# Alpha AI — Code Patterns Reference (Python / FastAPI)

> This file contains Python/FastAPI-specific patterns. For other languages:
> - [CODE_PATTERNS_NESTJS.md](CODE_PATTERNS_NESTJS.md) — NestJS / TypeScript patterns
> - [CODE_PATTERNS_SPRINGBOOT.md](CODE_PATTERNS_SPRINGBOOT.md) — Spring Boot / Java patterns

This file is loaded on-demand when writing Python backend code.

## Layer Segregation Patterns:

**app/api/** — Route definitions ONLY
```python
# CORRECT: Thin controller
@router.get("/users/{user_id}")
async def get_user(user_id: UUID, user_service: UserService = Depends()):
    return await user_service.get_by_id(user_id)

# WRONG: Business logic in route
@router.get("/users/{user_id}")
async def get_user(user_id: UUID, db: AsyncSession = Depends()):
    user = await db.execute(select(User).where(User.id == user_id))  # NO!
```

**app/services/** — Business logic ONLY
```python
# CORRECT: Uses repository
class UserService:
    async def get_by_id(self, user_id: UUID) -> UserResponse:
        user = await self.user_repo.get(user_id)
        if not user:
            raise NotFoundException("User not found")
        return UserResponse.model_validate(user)

# WRONG: Direct DB query
class UserService:
    async def get_by_id(self, user_id: UUID):
        async with AsyncSession() as session:  # NO! Use repository
            ...
```

**app/repositories/** — Data access ONLY
```python
# CORRECT: Pure CRUD
class UserRepo:
    async def get(self, user_id: UUID) -> User | None:
        result = await self.session.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

# WRONG: Business logic in repo
class UserRepo:
    async def get_active_premium_users(self):
        # Complex business filtering = belongs in service layer
```

## File Upload Pattern (Presigned URL):
```python
# CORRECT: Presigned URL — frontend uploads directly to S3
# Auth is handled by AuthMiddleware — user available on request.state.user
@router.post("/upload/presigned-url")
async def get_presigned_url(request: Request, req: UploadRequest):
    user = request.state.user  # Already authenticated by AuthMiddleware
    url = await storage_service.generate_presigned_url(
        bucket=settings.S3_BUCKET, key=f"uploads/{user.id}/{uuid4()}/{req.filename}",
        content_type=req.content_type, expires_in=3600,
    )
    return {"upload_url": url, "file_key": key}

# WRONG: Accepting file in API body (blocks server, memory issues)
@router.post("/upload")
async def upload(file: UploadFile):  # NO! Use presigned URLs instead
    contents = await file.read()
```

## RBAC Pattern:
```python
# CORRECT: RBAC handled by RBACMiddleware — controller is thin
# Auth + RBAC already verified by AuthMiddleware + RBACMiddleware
@router.delete("/users/{user_id}")
async def delete_user(request: Request, user_id: UUID, admin_service: AdminService = Depends()):
    # Auth + RBAC already verified by AuthMiddleware + RBACMiddleware
    return await admin_service.delete_user(user_id, deleted_by=request.state.user.id)

# For granular per-action permission checks beyond path-based RBAC,
# use a thin helper that reads from request.state.user.permissions:
async def require_permission(request: Request, permission: str):
    user = request.state.user
    user_perms = {p.name for p in user.role_obj.permissions}
    if permission not in user_perms:
        raise HTTPException(status_code=403, detail=f"Missing permission: {permission}")

# WRONG: Auth check in route handler — NEVER do this
@router.delete("/users/{user_id}")
async def delete_user(user_id: UUID, user: User = Depends(get_current_user)):  # NO!
    if user.role != "admin":  # NO! Use RBAC middleware
        raise ForbiddenException()
```

## Auth Middleware Pattern (HARD RULE — ALL auth in middleware):

```
# ┌─────────────────────────────────────────────────────────────────┐
# │  HARD RULE: ALL auth verification happens in MIDDLEWARE —       │
# │  NEVER in individual route handlers.                            │
# │  ❌ NEVER: user: User = Depends(get_current_user) in routes    │
# │  ❌ NEVER: if not token: raise HTTPException in route handlers  │
# │  ✅ ALWAYS: AuthMiddleware validates JWT, attaches to request   │
# │  ✅ ALWAYS: Routes access user via request.state.user           │
# └─────────────────────────────────────────────────────────────────┘
```

```python
# CORRECT: Auth middleware — validates JWT on every request
# app/core/auth_middleware.py
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse
from jose import jwt, JWTError
from app.core.config import settings
from app.core.redis import redis_client
from app.repositories.sql.user_repo import UserRepo

# Routes that do NOT require authentication
PUBLIC_PATHS = [
    "/api/v1/auth/login",
    "/api/v1/auth/register",
    "/api/v1/auth/refresh",
    "/api/v1/auth/google",
    "/api/v1/auth/google/callback",
    "/api/v1/auth/forgot-password",
    "/api/v1/auth/reset-password",
    "/api/v1/health",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/.well-known/agent.json",
]

class AuthMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, user_repo: UserRepo):
        super().__init__(app)
        self.user_repo = user_repo

    async def dispatch(self, request: Request, call_next):
        # Skip auth for public paths
        if any(request.url.path.startswith(p) for p in PUBLIC_PATHS):
            request.state.user = None
            return await call_next(request)

        # Extract JWT from HTTP-Only cookie (NEVER from Authorization header)
        token = request.cookies.get("access_token")
        if not token:
            return JSONResponse(
                status_code=401,
                content={"detail": "Authentication required"},
            )

        try:
            # Check Redis blacklist (logout support)
            if await redis_client.get(f"blacklist:{token}"):
                return JSONResponse(
                    status_code=401,
                    content={"detail": "Token has been revoked"},
                )

            # Decode and validate JWT
            payload = jwt.decode(
                token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM]
            )
            user_id = payload.get("sub")
            if not user_id:
                return JSONResponse(
                    status_code=401, content={"detail": "Invalid token payload"}
                )

            # Attach user to request state
            user = await self.user_repo.get(user_id)
            if not user or not user.is_active:
                return JSONResponse(
                    status_code=401, content={"detail": "User not found or inactive"}
                )
            request.state.user = user

        except JWTError:
            return JSONResponse(
                status_code=401, content={"detail": "Invalid or expired token"}
            )

        return await call_next(request)


# CORRECT: Register middleware in main.py
# app/main.py
from app.core.auth_middleware import AuthMiddleware

app = FastAPI(title=settings.PROJECT_NAME)
app.add_middleware(AuthMiddleware, user_repo=UserRepo(session_factory))
```

```python
# CORRECT: Route accesses user from request.state (set by middleware)
# app/api/v1/users.py
@router.get("/users/{user_id}")
async def get_user(request: Request, user_id: UUID, user_service: UserService = Depends()):
    current_user = request.state.user  # Already authenticated by middleware
    return await user_service.get_by_id(user_id)

@router.get("/users/me")
async def get_me(request: Request, user_service: UserService = Depends()):
    return await user_service.get_by_id(request.state.user.id)

# WRONG: Auth check in route handler — NEVER do this
@router.get("/users/{user_id}")
async def get_user(user_id: UUID, user: User = Depends(get_current_user)):  # NO!
    ...
```

```python
# CORRECT: RBAC permission middleware (also middleware-layer, not route-level)
# app/core/rbac_middleware.py
from functools import wraps
from starlette.requests import Request
from starlette.responses import JSONResponse

# Permission mapping: path prefix -> required permissions
RBAC_RULES = {
    "/api/v1/admin/": {"roles": ["admin", "superadmin"]},
    "/api/v1/admin/users": {"permissions": ["users:manage"]},
}

class RBACMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        user = getattr(request.state, "user", None)
        if not user:
            return await call_next(request)  # AuthMiddleware handles unauthed

        for path_prefix, rules in RBAC_RULES.items():
            if request.url.path.startswith(path_prefix):
                if "roles" in rules and user.role not in rules["roles"]:
                    return JSONResponse(
                        status_code=403,
                        content={"detail": "Insufficient role"},
                    )
                if "permissions" in rules:
                    user_perms = {p.name for p in user.role_obj.permissions}
                    if not all(p in user_perms for p in rules["permissions"]):
                        return JSONResponse(
                            status_code=403,
                            content={"detail": "Missing required permissions"},
                        )
        return await call_next(request)

# Register AFTER AuthMiddleware (order matters — last added runs first in Starlette)
app.add_middleware(RBACMiddleware)
app.add_middleware(AuthMiddleware, user_repo=UserRepo(session_factory))
```

## Dependency Injection (FastAPI Depends):
```python
# deps.py — Session factory and convenience helpers
async def get_mysql_session() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session

# deps.py — Helper to get user from request state (set by AuthMiddleware)
# This is a convenience dependency — NOT for auth verification (middleware does that)
async def get_current_user_from_state(request: Request) -> User:
    """Access the authenticated user set by AuthMiddleware.
    NEVER use this for auth checking — middleware already did it."""
    user = getattr(request.state, "user", None)
    if not user:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return user

# For services that need the user, use request.state.user directly
# or this convenience dependency — but remember auth is in middleware
```

## Async Everything:
```python
# All DB operations async
async def create_user(self, data: UserCreate) -> User:
    ...

# NEVER synchronous DB calls
def create_user(self, data: UserCreate) -> User:  # NO!
    ...
```

## Google OAuth2 Pattern (authlib):
```python
# CORRECT: Server-side OAuth2 Authorization Code Grant
# app/core/oauth.py
from authlib.integrations.starlette_client import OAuth

oauth = OAuth()
oauth.register(
    name="google",
    client_id=settings.GOOGLE_CLIENT_ID,
    client_secret=settings.GOOGLE_CLIENT_SECRET,
    server_metadata_url="https://accounts.google.com/.well-known/openid-configuration",
    client_kwargs={"scope": "openid email profile"},
)

# app/api/v1/auth.py
@router.get("/google")
async def google_login(request: Request):
    return await oauth.google.authorize_redirect(request, settings.GOOGLE_REDIRECT_URI)

@router.get("/google/callback")
async def google_callback(request: Request, response: Response):
    token = await oauth.google.authorize_access_token(request)
    user_info = token.get("userinfo")
    user = await auth_service.google_login_or_register(
        email=user_info["email"], name=user_info.get("name"), picture=user_info.get("picture"),
        google_sub=user_info["sub"],
    )
    set_auth_cookies(response, create_access_token(user.id), create_refresh_token(user.id))
    return RedirectResponse(url=settings.FRONTEND_URL + "/dashboard")

# WRONG: Client-side Google token validation
@router.post("/google")
async def google_login(token: str):  # NO! Never trust client-side tokens
    decoded = verify_google_token(token)  # NO! Use server-side flow
```

## Email Sending Pattern (Celery + fastapi-mail):
```python
# CORRECT: Async email via Celery task
# app/services/email_service.py
class EmailService:
    async def send_welcome(self, user: User):
        send_email_task.delay(
            to=user.email, subject="Welcome!",
            template="welcome.html", context={"name": user.display_name}
        )

    async def send_otp(self, email: str, otp: str):
        send_email_task.delay(
            to=email, subject=f"Your OTP: {otp}",
            template="verify_otp.html", context={"otp": otp, "expiry": 5}
        )

# app/tasks/email_tasks.py
@celery_app.task(name="email.send", autoretry_for=(Exception,), max_retries=3)
def send_email_task(to: str, subject: str, template: str, context: dict):
    html = jinja_env.get_template(template).render(**context)
    # Send via fastapi-mail or smtplib

# WRONG: Blocking email in API handler
@router.post("/register")
async def register(data: RegisterRequest):
    user = await auth_service.register(data)
    await smtp.send_email(user.email, ...)  # NO! Blocks API response
    return user
```

## Mobile Auth Pattern (expo-secure-store):
```python
# Backend: Mobile-specific token endpoint (returns JSON, not cookies)
# CORRECT: Return tokens as JSON for mobile clients
@router.post("/auth/login/mobile")
async def mobile_login(data: LoginRequest, request: Request):
    user = await auth_service.authenticate(data.email, data.password)
    access = create_access_token(user.id)
    refresh = create_refresh_token(user.id)
    return {"access_token": access, "refresh_token": refresh, "user": UserResponse.from_orm(user)}

# WRONG: Trying to use HTTP-only cookies for mobile
@router.post("/auth/login")
async def login(data: LoginRequest, response: Response):
    # Mobile apps CAN'T read HTTP-only cookies!
    response.set_cookie("access_token", token, httponly=True)  # NO! Mobile can't use this
```

```typescript
// Mobile: Token storage + Axios interceptor
// CORRECT: expo-secure-store + interceptor
import * as SecureStore from 'expo-secure-store';

const api = axios.create({ baseURL: process.env.EXPO_PUBLIC_API_URL });

api.interceptors.request.use(async (config) => {
  const token = await SecureStore.getItemAsync('access_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(null, async (error) => {
  if (error.response?.status === 401) {
    const refresh = await SecureStore.getItemAsync('refresh_token');
    const { data } = await axios.post('/auth/refresh', { token: refresh });
    await SecureStore.setItemAsync('access_token', data.access_token);
    error.config.headers.Authorization = `Bearer ${data.access_token}`;
    return api(error.config); // Retry original request
  }
  return Promise.reject(error);
});

// WRONG: Storing tokens in AsyncStorage
import AsyncStorage from '@react-native-async-storage/async-storage';
await AsyncStorage.setItem('token', jwt);  // NO! Not encrypted!
```

## Point Deduction Pattern (GenAI endpoints):
```python
# CORRECT: Use require_points dependency for metered actions
# Auth is handled by AuthMiddleware — user available on request.state.user
@router.post("/ai/generate")
async def generate(
    request: Request,
    req: GenerateRequest,
    _points: None = Depends(require_points(cost=10)),  # Auto checks + deducts
):
    user = request.state.user  # Already authenticated by AuthMiddleware
    result = await ai_service.generate(req)
    return result  # X-Points-Remaining header auto-added by middleware

# CORRECT: require_points dependency reads user from request.state
async def require_points(cost: int):
    async def checker(request: Request):
        user = request.state.user  # Set by AuthMiddleware
        balance = await point_service.check_balance(user.id)
        if balance < cost:
            raise HTTPException(
                status_code=402,
                detail={
                    "error": "insufficient_points",
                    "required": cost, "balance": balance,
                    "topup_packs": await point_service.get_topup_packs(),
                }
            )
        await point_service.deduct(user.id, cost, action="ai_generation")
    return Depends(checker)

# WRONG: No point check on GenAI endpoint (unlimited access)
@router.post("/ai/generate")
async def generate(request: Request, req: GenerateRequest):
    return await ai_service.generate(req)  # NO! No point gate = cost leak
```

## Top-Up Purchase Pattern:
```python
# CORRECT: Top-up via Razorpay one-time order
# Auth is handled by AuthMiddleware — user available on request.state.user
@router.post("/points/topup")
async def purchase_topup(request: Request, req: TopupRequest):
    user = request.state.user  # Already authenticated by AuthMiddleware
    pack = TOPUP_PACKS[req.pack_id]  # Server-side lookup, never trust client price
    order = await point_service.create_topup_order(user.id, pack)
    return {"order_id": order.razorpay_order_id, "key_id": settings.RAZORPAY_KEY_ID}
```

## Webhook Pattern:
```python
# CORRECT: Verify signature, deduplicate, process async
@router.post("/webhooks/razorpay")
async def razorpay_webhook(request: Request):
    body = await request.body()
    signature = request.headers.get("X-Razorpay-Signature")
    webhook_service.verify_signature(body, signature)  # Raises if invalid
    event = json.loads(body)
    if await redis.exists(f"rzp_webhook:{event['event_id']}"):
        return {"status": "already_processed"}  # Idempotent
    await redis.set(f"rzp_webhook:{event['event_id']}", "1", ex=172800)
    process_webhook_task.delay(event)  # Celery async
    # Handles: subscription.activated -> credit plan points
    #          subscription.charged -> reset plan points (renewal)
    #          payment.captured -> credit topup points (if topup order)
    #          subscription.cancelled -> mark for downgrade at cycle end
    return {"status": "ok"}
```

## GenAI Gateway Pattern (LiteLLM):
```python
# CORRECT: LiteLLM unified gateway with model registry
# app/ai/gateway.py
import litellm

MODEL_REGISTRY = {
    "fast": "gpt-4o-mini",              # Quick, cheap tasks
    "smart": "claude-sonnet-4-6",        # Complex reasoning
    "premium": "claude-opus-4-6",        # Highest quality
    "gemini": "gemini/gemini-2.5-pro",   # Google ecosystem
    "local": "ollama/llama3.2",          # Local/private data
}

async def generate(prompt: str, model_tier: str = "smart", stream: bool = True):
    model = MODEL_REGISTRY.get(model_tier, MODEL_REGISTRY["smart"])
    return await litellm.acompletion(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        stream=stream,
        fallbacks=["claude-sonnet-4-6", "gpt-4o", "gemini/gemini-2.5-pro"],
    )

# WRONG: Direct provider SDK (locked to one LLM)
import openai
client = openai.OpenAI()  # NO! Use LiteLLM gateway
response = client.chat.completions.create(...)  # NO! Provider lock-in
```

## RAG Retrieval Pattern:
```python
# CORRECT: Hybrid retrieval with vector + keyword search
# app/ai/rag/retriever.py
async def retrieve(query: str, top_k: int = 5) -> list[dict]:
    embedding = await litellm.aembedding(model="text-embedding-3-large", input=query)
    results = qdrant.search(collection="docs", query_vector=embedding, limit=top_k)
    return [{"text": r.payload["text"], "score": r.score} for r in results]

# WRONG: Stuffing full docs into context
messages = [{"role": "user", "content": f"{all_docs}\n{query}"}]  # NO! Token waste
```

## AI Streaming SSE Pattern:
```python
# CORRECT: SSE streaming for AI chat
# Auth is handled by AuthMiddleware — user available on request.state.user
@router.post("/ai/chat")
async def chat(request: Request, req: ChatRequest):
    user = request.state.user  # Already authenticated by AuthMiddleware
    async def stream():
        async for chunk in ai_gateway.generate(req.message, stream=True):
            content = chunk.choices[0].delta.content or ""
            if content:
                yield f"data: {json.dumps({'content': content})}\n\n"
        yield "data: [DONE]\n\n"
    return StreamingResponse(stream(), media_type="text/event-stream")

# WRONG: Waiting for full AI response before returning
response = await litellm.acompletion(...)  # Blocks for 5-30 seconds
return {"text": response.choices[0].message.content}  # NO! Stream it
```

## MCP Prompt Server Pattern:
```python
# CORRECT: Expose reusable prompts via MCP server
# app/ai/mcp/prompt_server.py
from mcp.server import Server
from mcp.types import Prompt, PromptArgument, PromptMessage, TextContent

server = Server("alpha-ai-prompts")

@server.list_prompts()
async def list_prompts() -> list[Prompt]:
    return [
        Prompt(
            name="code_review",
            title="Review Code",
            description="Analyze code quality and suggest improvements",
            arguments=[
                PromptArgument(name="code", description="Code to review", required=True),
                PromptArgument(name="language", description="Programming language", required=False),
            ],
        ),
        Prompt(
            name="summarize_document",
            title="Summarize Document",
            description="Generate concise summary of a document",
            arguments=[
                PromptArgument(name="content", description="Document content", required=True),
            ],
        ),
    ]

@server.get_prompt()
async def get_prompt(name: str, arguments: dict) -> list[PromptMessage]:
    template = await load_prompt_template(name)  # Load from app/ai/prompts/
    rendered = template.render(**arguments)
    return [PromptMessage(role="user", content=TextContent(type="text", text=rendered))]
```

## A2A Agent Card Pattern:
```python
# CORRECT: Expose agent capabilities via A2A Agent Card
# app/ai/a2a/agent_card.py
AGENT_CARD = {
    "name": "alpha-ai-assistant",
    "description": "Alpha AI's intelligent assistant with RAG, code generation, and analysis",
    "url": "https://api.example.com/a2a",
    "version": "1.0.0",
    "capabilities": {
        "streaming": True,
        "pushNotifications": False,
    },
    "skills": [
        {
            "id": "document-analysis",
            "name": "Document Analysis",
            "description": "Analyze and extract insights from uploaded documents using RAG",
            "tags": ["rag", "analysis", "documents"],
        },
        {
            "id": "code-generation",
            "name": "Code Generation",
            "description": "Generate code based on natural language descriptions",
            "tags": ["code", "generation", "development"],
        },
    ],
    "authentication": {
        "schemes": ["bearer"],
    },
}

@router.get("/.well-known/agent.json")
async def get_agent_card():
    """A2A Agent Card discovery endpoint."""
    return AGENT_CARD
```

## Structured Output Pattern (instructor):
```python
# CORRECT: Pydantic-validated LLM output
# app/ai/structured/extractor.py
import instructor
import litellm

client = instructor.from_litellm(litellm.acompletion)

class ProductReview(BaseModel):
    sentiment: Literal["positive", "negative", "neutral"]
    score: float = Field(ge=0, le=1)
    key_points: list[str]
    summary: str

async def extract_review(text: str) -> ProductReview:
    return await client.chat.completions.create(
        model="claude-sonnet-4-6",
        response_model=ProductReview,
        messages=[{"role": "user", "content": f"Analyze this review:\n{text}"}],
        max_retries=2,  # Auto-retry on validation failure
    )

# WRONG: Parsing raw text with regex
import re
sentiment = re.search(r"sentiment: (\w+)", response)  # NO! Use structured output
```

## Semantic Caching Pattern:
```python
# CORRECT: Redis + embedding similarity cache
# app/ai/cache/semantic_cache.py
import numpy as np

CACHE_THRESHOLD = 0.95  # Cosine similarity threshold

async def get_cached_response(query: str) -> str | None:
    query_embedding = await embed_text(query)
    cached_keys = await redis.keys("ai:cache:*")
    for key in cached_keys:
        cached = json.loads(await redis.get(key))
        similarity = cosine_similarity(query_embedding, cached["embedding"])
        if similarity > CACHE_THRESHOLD:
            return cached["response"]
    return None

async def cache_response(query: str, response: str):
    embedding = await embed_text(query)
    cache_key = f"ai:cache:{hashlib.md5(query.encode()).hexdigest()}"
    await redis.set(cache_key, json.dumps({
        "embedding": embedding, "response": response, "query": query,
    }), ex=86400)  # 24h TTL
```

## Agentic RAG Pattern:
```python
# CORRECT: Agent dynamically decides retrieval strategy
# app/ai/rag/agentic_retriever.py
from google.adk.agents import Agent
from google.adk.tools import FunctionTool

rag_agent = Agent(
    name="rag_agent",
    model=LiteLlm(model="claude-sonnet-4-6"),
    instruction="""You are a retrieval agent. Given a user query:
    1. Decide which knowledge base(s) to search
    2. If query is complex, decompose into sub-queries
    3. If retrieved context is insufficient, search the web
    4. Re-rank results by relevance before returning""",
    tools=[
        FunctionTool(search_vector_db),      # Vector search in Qdrant
        FunctionTool(search_keyword),         # BM25 keyword search
        FunctionTool(search_web),             # Web search fallback
        FunctionTool(decompose_query),        # Split complex queries
        FunctionTool(rerank_results),         # Re-rank with Cohere/FlashRank
    ],
)

# WRONG: Single-shot naive retrieval
results = qdrant.search(query)  # NO! Use agentic retrieval for complex queries
```

## Re-ranking Pattern:
```python
# CORRECT: Re-rank after vector retrieval
# app/ai/reranker/reranker.py
import cohere

co = cohere.Client(settings.COHERE_API_KEY)

async def rerank(query: str, documents: list[str], top_n: int = 5) -> list[dict]:
    results = co.rerank(
        query=query,
        documents=documents,
        top_n=top_n,
        model="rerank-v3.5",
    )
    return [{"text": documents[r.index], "score": r.relevance_score} for r in results.results]

# Pipeline: retrieve(top_k=20) -> rerank(top_n=5) -> generate
raw_results = await vector_search(query, top_k=20)
reranked = await rerank(query, [r["text"] for r in raw_results], top_n=5)
context = "\n".join([r["text"] for r in reranked])
response = await ai_gateway.generate(f"Context:\n{context}\n\nQuestion: {query}")
```

## AI Evaluation Pattern (DeepEval):
```python
# CORRECT: LLM unit tests with DeepEval
# tests/ai/test_ai_quality.py
from deepeval import assert_test
from deepeval.test_case import LLMTestCase
from deepeval.metrics import AnswerRelevancyMetric, FaithfulnessMetric, HallucinationMetric

def test_chat_relevancy():
    test_case = LLMTestCase(
        input="What is our refund policy?",
        actual_output=ai_response,
        retrieval_context=["Refunds within 30 days of purchase..."],
    )
    assert_test(test_case, [
        AnswerRelevancyMetric(threshold=0.7),
        FaithfulnessMetric(threshold=0.8),
        HallucinationMetric(threshold=0.5),
    ])
```

## Context Window Management Pattern:
```python
# CORRECT: Auto-summarize when conversation exceeds threshold
# app/ai/context/summarizer.py
import tiktoken

MAX_CONTEXT_TOKENS = 8000  # Leave room for response
SUMMARY_THRESHOLD = 6000

async def manage_context(messages: list[dict]) -> list[dict]:
    enc = tiktoken.encoding_for_model("gpt-4o")
    total_tokens = sum(len(enc.encode(m["content"])) for m in messages)
    if total_tokens > SUMMARY_THRESHOLD:
        old_messages = messages[1:-4]  # Keep system prompt + last 4 messages
        summary = await ai_gateway.generate(
            f"Summarize this conversation:\n{format_messages(old_messages)}",
            model_tier="fast",
        )
        return [messages[0], {"role": "system", "content": f"Summary: {summary}"}] + messages[-4:]
    return messages
```

## Human-in-the-Loop Pattern:
```python
# CORRECT: Review queue for AI content
# Auth is handled by AuthMiddleware — user available on request.state.user
# app/ai/hitl/review_queue.py
@router.post("/ai/generate-with-review")
async def generate_with_review(request: Request, req: GenerateRequest):
    user = request.state.user  # Already authenticated by AuthMiddleware
    result = await ai_gateway.generate(req.prompt)
    confidence = result.metadata.get("confidence", 0.5)
    if confidence >= settings.AI_AUTO_PUBLISH_THRESHOLD:
        return {"content": result.text, "status": "auto_approved"}
    review_item = await review_service.create(
        content=result.text, user_id=user.id, confidence=confidence,
    )
    return {"review_id": review_item.id, "status": "pending_review"}
```

## Voice AI Pattern:
```python
# CORRECT: Speech-to-text + Text-to-speech
# app/ai/voice/stt.py
async def transcribe(audio_file: UploadFile) -> str:
    response = await litellm.atranscription(
        model="whisper-1", file=audio_file.file,
    )
    return response.text

# app/ai/voice/tts.py
async def text_to_speech(
    text: str,
    provider: str = "openai",  # "openai" | "gemini" | "elevenlabs"
) -> AsyncGenerator[bytes, None]:
    # LiteLLM routes to correct provider
    model_map = {
        "openai": "tts-1",           # OpenAI TTS
        "gemini": "gemini/tts-1",    # Gemini TTS
        "elevenlabs": "elevenlabs/eleven_multilingual_v2",  # ElevenLabs
    }
    response = await litellm.aspeech(
        model=model_map[provider], input=text, voice="alloy",
    )
    async for chunk in response.iter_bytes():
        yield chunk
```

## Batch Processing Pattern:
```python
# CORRECT: Background batch AI ops with progress tracking
# app/ai/batch/batch_processor.py
@celery_app.task(bind=True, name="ai.batch_embed")
def batch_embed_documents(self, document_ids: list[str], user_id: str):
    total = len(document_ids)
    for i, doc_id in enumerate(document_ids):
        doc = load_document(doc_id)
        chunks = chunker.chunk(doc.text)
        embeddings = embed_texts([c.text for c in chunks])
        vector_store.upsert(doc_id, chunks, embeddings)
        # Update progress in Redis
        redis.set(f"batch:{self.request.id}:progress", json.dumps({
            "completed": i + 1, "total": total,
            "percent": round((i + 1) / total * 100),
        }), ex=3600)
    return {"status": "completed", "processed": total}
```

## Error Handling:
```python
# Custom exceptions in core/exceptions.py
class AppException(Exception):
    """Base exception for all application errors."""
    status_code: int = 500
    detail: str = "Internal server error"

    def __init__(self, detail: str | None = None, status_code: int | None = None):
        self.detail = detail or self.__class__.detail
        self.status_code = status_code or self.__class__.status_code
        super().__init__(self.detail)

class NotFoundException(AppException):
    status_code = 404
    detail = "Resource not found"

class UnauthorizedException(AppException):
    status_code = 401
    detail = "Not authenticated"

class ForbiddenException(AppException):
    status_code = 403
    detail = "Access forbidden"

class ValidationException(AppException):
    status_code = 422
    detail = "Validation failed"

class ConflictException(AppException):
    status_code = 409
    detail = "Resource conflict"

class RateLimitException(AppException):
    status_code = 429
    detail = "Too many requests"

class InsufficientPointsException(AppException):
    status_code = 402
    detail = "Insufficient points"

# Raise in services, catch in middleware — never in repos
```

```python
# CORRECT: Global exception handler middleware — catches all AppException subclasses
# app/core/exception_handler.py
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse
from app.core.exceptions import AppException
import traceback
import logging

logger = logging.getLogger(__name__)

class ExceptionHandlerMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        try:
            response = await call_next(request)
            return response
        except AppException as exc:
            # Known application errors — return structured JSON
            return JSONResponse(
                status_code=exc.status_code,
                content={
                    "detail": exc.detail,
                    "error_type": exc.__class__.__name__,
                },
            )
        except Exception as exc:
            # Unknown errors — log full traceback, return generic 500
            logger.error(
                f"Unhandled exception on {request.method} {request.url.path}: "
                f"{exc.__class__.__name__}: {exc}\n{traceback.format_exc()}"
            )
            return JSONResponse(
                status_code=500,
                content={"detail": "Internal server error"},
            )

# WRONG: Try/except in every route handler
@router.get("/users/{user_id}")
async def get_user(request: Request, user_id: UUID):
    try:  # NO! Exception handling belongs in middleware
        user = await user_service.get_by_id(user_id)
        return user
    except NotFoundException as e:
        return JSONResponse(status_code=404, content={"detail": str(e)})  # NO!
```

## Rate Limiting Middleware Pattern:
```python
# CORRECT: Rate limiting in middleware — NOT in individual route handlers
# app/core/rate_limit_middleware.py
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse
from app.core.redis import redis_client
import time

# Rate limit rules per path prefix (requests per window)
RATE_LIMIT_RULES = {
    "/api/v1/auth/login": {"max_requests": 5, "window_seconds": 300},      # 5 per 5 min
    "/api/v1/auth/register": {"max_requests": 3, "window_seconds": 3600},   # 3 per hour
    "/api/v1/auth/forgot-password": {"max_requests": 3, "window_seconds": 3600},
    "/api/v1/ai/": {"max_requests": 30, "window_seconds": 60},             # 30 per min for AI
    "/api/v1/": {"max_requests": 100, "window_seconds": 60},               # 100 per min default
}

class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Determine client identifier (user ID if authenticated, else IP)
        user = getattr(request.state, "user", None)
        client_id = str(user.id) if user else request.client.host

        # Find matching rate limit rule (most specific path first)
        rule = None
        for path_prefix in sorted(RATE_LIMIT_RULES.keys(), key=len, reverse=True):
            if request.url.path.startswith(path_prefix):
                rule = RATE_LIMIT_RULES[path_prefix]
                break

        if rule:
            key = f"rate_limit:{client_id}:{request.url.path}"
            current = await redis_client.get(key)

            if current and int(current) >= rule["max_requests"]:
                ttl = await redis_client.ttl(key)
                return JSONResponse(
                    status_code=429,
                    content={
                        "detail": "Too many requests",
                        "retry_after": ttl,
                    },
                    headers={"Retry-After": str(ttl)},
                )

            pipe = redis_client.pipeline()
            pipe.incr(key)
            pipe.expire(key, rule["window_seconds"])
            await pipe.execute()

        return await call_next(request)

# WRONG: Rate limiting in individual routes
@router.post("/auth/login")
async def login(request: Request, data: LoginRequest):
    ip = request.client.host
    count = await redis.get(f"login_attempts:{ip}")  # NO! Use middleware
    if count and int(count) > 5:
        raise HTTPException(status_code=429, detail="Too many attempts")  # NO!
```

## CORS Middleware Pattern:
```python
# CORRECT: CORS configuration in middleware — centralized, not per-route
# app/core/cors.py
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings

def setup_cors(app):
    """Configure CORS middleware. Called once in main.py."""
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,  # ["https://app.example.com"]
        allow_credentials=True,                # Required for HTTP-Only cookies
        allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
        allow_headers=["Content-Type", "X-CSRF-Token"],
        expose_headers=["X-Points-Remaining", "X-Request-ID"],
        max_age=600,  # Cache preflight for 10 minutes
    )

# WRONG: CORS headers in individual route handlers
@router.get("/users")
async def get_users(request: Request):
    response = JSONResponse(content=users)
    response.headers["Access-Control-Allow-Origin"] = "*"  # NO! Wildcard + credentials = insecure
    return response
```

## Middleware Registration Order (CRITICAL):
```python
# CORRECT: Middleware registration order in main.py
# Starlette processes middleware in REVERSE registration order:
# Last registered = first to execute on request
# First registered = last to execute on request (closest to route handler)
#
# Request flow:  CORS -> ExceptionHandler -> RateLimit -> Auth -> RBAC -> Route
# Response flow: Route -> RBAC -> Auth -> RateLimit -> ExceptionHandler -> CORS
#
# app/main.py
from fastapi import FastAPI
from app.core.config import settings
from app.core.cors import setup_cors
from app.core.exception_handler import ExceptionHandlerMiddleware
from app.core.rate_limit_middleware import RateLimitMiddleware
from app.core.auth_middleware import AuthMiddleware
from app.core.rbac_middleware import RBACMiddleware
from app.repositories.sql.user_repo import UserRepo
from app.core.database import session_factory

app = FastAPI(title=settings.PROJECT_NAME, version=settings.VERSION)

# Register middleware — REVERSE ORDER (last added = first to run)
# 1. RBAC (closest to route — runs last on request, first on response)
app.add_middleware(RBACMiddleware)
# 2. Auth — validates JWT, attaches user to request.state
app.add_middleware(AuthMiddleware, user_repo=UserRepo(session_factory))
# 3. Rate limiting — checks request rate before auth
app.add_middleware(RateLimitMiddleware)
# 4. Exception handler — catches all errors from inner middleware + routes
app.add_middleware(ExceptionHandlerMiddleware)
# 5. CORS — runs first on request (handles preflight), last on response (adds headers)
setup_cors(app)

# WRONG: Random middleware order
app.add_middleware(AuthMiddleware, user_repo=UserRepo(session_factory))
app.add_middleware(RBACMiddleware)  # NO! RBAC before Auth means no user on request.state
app.add_middleware(ExceptionHandlerMiddleware)  # NO! Won't catch Auth/RBAC errors
```

## Request Lifecycle Summary:
```python
# The complete request lifecycle with middleware-layer auth:
#
# 1. CLIENT sends HTTPS request with HTTP-Only cookie (access_token)
#    │
# 2. CORS Middleware
#    ├── Preflight (OPTIONS)? → Return 200 with CORS headers, skip everything else
#    └── Regular request? → Add CORS headers to response, continue
#    │
# 3. ExceptionHandler Middleware
#    └── Wraps everything in try/except — catches AppException + unhandled errors
#    │
# 4. RateLimit Middleware
#    ├── Check Redis counter for client IP / user ID
#    ├── Over limit? → Return 429 Too Many Requests
#    └── Under limit? → Increment counter, continue
#    │
# 5. AuthMiddleware
#    ├── Public path? → Set request.state.user = None, skip auth
#    ├── No cookie? → Return 401 Authentication required
#    ├── Token blacklisted in Redis? → Return 401 Token revoked
#    ├── JWT decode fails? → Return 401 Invalid token
#    ├── User not found / inactive? → Return 401 User not found
#    └── Valid? → Set request.state.user = User object, continue
#    │
# 6. RBACMiddleware
#    ├── No user (public path)? → Skip, continue
#    ├── Path matches RBAC rule? → Check role + permissions
#    ├── Insufficient role? → Return 403 Insufficient role
#    ├── Missing permission? → Return 403 Missing permissions
#    └── Authorized? → Continue to route handler
#    │
# 7. ROUTE HANDLER (thin controller)
#    ├── Access user via: request.state.user (already verified)
#    ├── Call service layer: await user_service.get_by_id(user_id)
#    └── Return response (service handles business logic)
#    │
# 8. Response flows back through middleware in reverse order
#    └── CORS headers added → Exception wrapping → Response to client
```
