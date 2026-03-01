# Language Profile: Node.js / NestJS

> Used by auto-build, init-project, and SKILL.md when backend_language = nodejs-nestjs

---

## Runtime

| Property           | Value                                                      |
|--------------------|------------------------------------------------------------|
| Language           | TypeScript (strict mode)                                   |
| Runtime            | Node.js 22 LTS                                             |
| Framework          | NestJS 11+                                                 |
| Package Manager    | pnpm                                                       |
| Dependency File    | package.json                                               |
| Lock File          | pnpm-lock.yaml                                             |
| Module System      | ESM (type: "module" in package.json)                       |
| Node Engine        | "engines": { "node": ">=22.0.0" }                         |

**Scaffold command:**
```bash
npx @nestjs/cli@latest new <project-name> --package-manager pnpm --skip-git --strict
```

After scaffolding, immediately install the core stack (see Core Dependencies below) and configure Prisma, auth, and Swagger.

---

## Directory Structure

```
<project-root>/
├── prisma/
│   ├── schema.prisma                     # Prisma schema (models, enums, relations)
│   └── migrations/                       # Auto-generated migration SQL files
├── src/
│   ├── main.ts                           # Bootstrap (entry point)
│   ├── app.module.ts                     # Root module — imports all feature modules
│   ├── config/
│   │   ├── app.config.ts                 # AppConfigService (PORT, NODE_ENV, CORS origins)
│   │   └── database.config.ts            # Database URL, pool size, logging
│   ├── prisma/
│   │   ├── prisma.service.ts             # Extends PrismaClient, onModuleInit/onModuleDestroy
│   │   └── prisma.module.ts              # Global module exporting PrismaService
│   ├── common/
│   │   ├── guards/
│   │   │   └── roles.guard.ts            # RBAC role-based guard
│   │   ├── interceptors/
│   │   │   ├── logging.interceptor.ts    # Request/response logging
│   │   │   └── transform.interceptor.ts  # Wrap responses in { data, meta }
│   │   ├── filters/
│   │   │   └── all-exceptions.filter.ts  # Global exception filter
│   │   ├── decorators/
│   │   │   ├── roles.decorator.ts        # @Roles('admin', 'user')
│   │   │   ├── current-user.decorator.ts # @CurrentUser() param decorator
│   │   │   └── public.decorator.ts       # @Public() — skip JWT guard
│   │   ├── pipes/
│   │   │   └── parse-uuid.pipe.ts        # UUID validation pipe
│   │   └── dto/
│   │       └── pagination.dto.ts         # Shared PaginationQueryDto
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── auth.module.ts
│   │   │   ├── auth.controller.ts
│   │   │   ├── auth.service.ts
│   │   │   ├── strategies/
│   │   │   │   └── jwt.strategy.ts       # Passport JWT strategy (reads cookie)
│   │   │   ├── guards/
│   │   │   │   └── jwt-auth.guard.ts     # Global JWT auth guard
│   │   │   └── dto/
│   │   │       ├── login.dto.ts
│   │   │       ├── register.dto.ts
│   │   │       └── auth-response.dto.ts
│   │   ├── users/
│   │   │   ├── users.module.ts
│   │   │   ├── users.controller.ts
│   │   │   ├── users.service.ts
│   │   │   ├── users.repository.ts       # Data-access layer (Prisma queries)
│   │   │   ├── entities/
│   │   │   │   └── user.entity.ts        # Response shape / type (NOT a DB model)
│   │   │   └── dto/
│   │   │       ├── create-user.dto.ts
│   │   │       └── update-user.dto.ts
│   │   └── health/
│   │       ├── health.module.ts
│   │       └── health.controller.ts      # /api/v1/health — liveness + readiness
│   └── shared/
│       ├── constants.ts                  # App-wide constants
│       └── utils/
│           ├── hash.util.ts              # bcrypt hash/compare wrappers
│           └── cookie.util.ts            # Set/clear auth cookie helpers
├── test/
│   ├── app.e2e-spec.ts                   # End-to-end tests
│   └── jest-e2e.json                     # E2E Jest config
├── .env.example
├── .eslintrc.js
├── .prettierrc
├── nest-cli.json
├── tsconfig.json
├── tsconfig.build.json
├── Dockerfile
├── docker-compose.yml
├── package.json
└── pnpm-lock.yaml
```

### Layer Segregation Rules (NestJS)

```
controller → service → repository → PrismaService
  NEVER: controller imports repository directly
  NEVER: service imports controller
  NEVER: repository contains business logic
  NEVER: business logic in controller (thin controllers only)
  NEVER: raw Prisma calls in service (use repository)
```

---

## Core Dependencies (package.json)

### Production

```json
{
  "dependencies": {
    "@nestjs/common": "^11.0.0",
    "@nestjs/core": "^11.0.0",
    "@nestjs/platform-express": "^11.0.0",
    "@nestjs/config": "^4.0.0",
    "@nestjs/swagger": "^11.0.0",
    "@nestjs/passport": "^11.0.0",
    "@nestjs/jwt": "^11.0.0",
    "@prisma/client": "^6.0.0",
    "passport": "^0.7.0",
    "passport-jwt": "^4.0.1",
    "bcryptjs": "^2.4.3",
    "class-validator": "^0.14.1",
    "class-transformer": "^0.5.1",
    "cookie-parser": "^1.4.7",
    "helmet": "^8.0.0",
    "compression": "^1.7.5",
    "rxjs": "^7.8.1",
    "reflect-metadata": "^0.2.2"
  }
}
```

### Install command

```bash
pnpm add @nestjs/common @nestjs/core @nestjs/platform-express @nestjs/config \
  @nestjs/swagger @nestjs/passport @nestjs/jwt @prisma/client \
  passport passport-jwt bcryptjs class-validator class-transformer \
  cookie-parser helmet compression rxjs reflect-metadata
```

---

## Conditional Dependencies

Only install if the project's PRD/feature set requires these capabilities.

| Feature          | Packages                                                             | When to include                      |
|------------------|----------------------------------------------------------------------|--------------------------------------|
| MongoDB          | `@nestjs/mongoose`, `mongoose`                                       | PRD mentions NoSQL / document store  |
| Redis / Cache    | `ioredis`, `@nestjs-modules/ioredis` or `cache-manager-ioredis-yet`  | Caching, sessions, rate-limiting     |
| Email            | `@nestjs-modules/mailer`, `nodemailer`, `handlebars`                 | Transactional email, OTP             |
| Queue / Jobs     | `@nestjs/bullmq`, `bullmq`                                          | Background jobs, async processing    |
| File Upload      | `@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`               | File/image upload via presigned URLs |
| Search           | `meilisearch`                                                        | Full-text search                     |
| WebSocket        | `@nestjs/websockets`, `@nestjs/platform-socket.io`, `socket.io`     | Real-time features, chat, live data  |
| Push Notifs      | `firebase-admin`                                                     | Mobile push notifications            |
| Error Tracking   | `@sentry/nestjs`                                                     | Production error monitoring          |
| Analytics        | `posthog-node`                                                       | Product analytics                    |
| 2FA / TOTP       | `otplib`, `qrcode`                                                   | Two-factor authentication            |
| Rate Limiting    | `@nestjs/throttler`                                                  | API rate limiting                    |
| Scheduling       | `@nestjs/schedule`                                                   | Cron jobs, periodic tasks            |
| GenAI (Vercel)   | `ai`, `@ai-sdk/openai`                                              | LLM integration via Vercel AI SDK    |
| GenAI (LangChain)| `@langchain/core`, `@langchain/openai`, `@langchain/langgraph`      | Agentic workflows                    |
| Vector DB        | `@qdrant/js-client-rest`                                             | RAG / semantic search                |
| Embeddings       | `@ai-sdk/openai` or `openai`                                        | Embedding generation                 |
| AI Observability | `langfuse`                                                           | LLM tracing and evaluation           |
| Structured Output| `zod` (with `ai` SDK `generateObject`)                              | Validated LLM extraction             |

---

## Dev Dependencies

```json
{
  "devDependencies": {
    "prisma": "^6.0.0",
    "@nestjs/cli": "^11.0.0",
    "@nestjs/schematics": "^11.0.0",
    "@nestjs/testing": "^11.0.0",
    "typescript": "^5.7.0",
    "ts-node": "^10.9.2",
    "jest": "^29.7.0",
    "ts-jest": "^29.2.0",
    "@types/jest": "^29.5.0",
    "supertest": "^7.0.0",
    "@types/supertest": "^6.0.0",
    "@types/node": "^22.0.0",
    "@types/express": "^5.0.0",
    "@types/passport-jwt": "^4.0.1",
    "@types/bcryptjs": "^2.4.6",
    "@types/cookie-parser": "^1.4.7",
    "@types/compression": "^1.7.5",
    "eslint": "^9.0.0",
    "@eslint/js": "^9.0.0",
    "typescript-eslint": "^8.0.0",
    "eslint-config-prettier": "^9.1.0",
    "eslint-plugin-prettier": "^5.2.0",
    "prettier": "^3.4.0",
    "source-map-support": "^0.5.21"
  }
}
```

---

## Config Files

### tsconfig.json

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2023",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strict": true,
    "strictNullChecks": true,
    "noImplicitAny": true,
    "strictBindCallApply": true,
    "forceConsistentCasingInFileNames": true,
    "noFallthroughCasesInSwitch": true,
    "paths": {
      "@/*": ["src/*"],
      "@modules/*": ["src/modules/*"],
      "@common/*": ["src/common/*"],
      "@config/*": ["src/config/*"]
    }
  }
}
```

### .prettierrc

```json
{
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2,
  "semi": true,
  "bracketSpacing": true,
  "arrowParens": "always",
  "endOfLine": "lf"
}
```

### nest-cli.json

```json
{
  "$schema": "https://json.schemastore.org/nest-cli",
  "collection": "@nestjs/schematics",
  "sourceRoot": "src",
  "compilerOptions": {
    "deleteOutDir": true,
    "plugins": ["@nestjs/swagger"]
  }
}
```

### .env.example

```env
# App
NODE_ENV=development
PORT=3000
API_PREFIX=api/v1

# Database (MySQL via Prisma)
DATABASE_URL="mysql://root:password@localhost:3306/myapp?connection_limit=10"

# JWT
JWT_SECRET=change-me-to-a-random-64-char-string
JWT_ACCESS_EXPIRY=30m
JWT_REFRESH_EXPIRY=7d

# Cookie
COOKIE_DOMAIN=localhost
COOKIE_SECURE=false
COOKIE_SAME_SITE=lax

# CORS
CORS_ORIGINS=http://localhost:3001,http://localhost:8081

# Redis (if used)
REDIS_URL=redis://localhost:6379

# S3 (if used)
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
S3_BUCKET=myapp-uploads

# Sentry (if used)
SENTRY_DSN=

# OpenAI (if GenAI used)
OPENAI_API_KEY=
```

---

## Entry Point: src/main.ts

```typescript
import { NestFactory } from '@nestjs/core';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import * as cookieParser from 'cookie-parser';
import helmet from 'helmet';
import * as compression from 'compression';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  });

  // --- Security ---
  app.use(helmet());
  app.use(compression());
  app.use(cookieParser());

  // --- CORS ---
  app.enableCors({
    origin: process.env.CORS_ORIGINS?.split(',') ?? ['http://localhost:3001'],
    credentials: true, // Required for cookie-based auth
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-CSRF-Token'],
  });

  // --- Global Prefix ---
  app.setGlobalPrefix('api/v1');

  // --- Validation ---
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,           // Strip unknown properties
      forbidNonWhitelisted: true, // Throw on unknown properties
      transform: true,           // Auto-transform payloads to DTO instances
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // --- Swagger / OpenAPI ---
  if (process.env.NODE_ENV !== 'production') {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('API Documentation')
      .setDescription('Auto-generated API docs')
      .setVersion('1.0')
      .addCookieAuth('access_token')
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('docs', app, document, {
      swaggerOptions: {
        persistAuthorization: true,
        withCredentials: true,
      },
    });
  }

  // --- Start ---
  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`Server running on http://localhost:${port}`);
  console.log(`Swagger docs at http://localhost:${port}/docs`);
}

bootstrap();
```

---

## Database Config: prisma/schema.prisma

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "mysql"
  url      = env("DATABASE_URL")
}

// ─── User Model ───────────────────────────────────────────

model User {
  id            String    @id @default(uuid())
  email         String    @unique
  passwordHash  String?   @map("password_hash")
  displayName   String    @map("display_name")
  avatarUrl     String?   @map("avatar_url")
  role          Role      @default(USER)
  isActive      Boolean   @default(true) @map("is_active")
  emailVerified Boolean   @default(false) @map("email_verified")

  // OAuth fields
  googleSub     String?   @unique @map("google_sub")
  authProvider  AuthProvider @default(LOCAL) @map("auth_provider")

  // Timestamps
  createdAt     DateTime  @default(now()) @map("created_at")
  updatedAt     DateTime  @updatedAt @map("updated_at")
  lastLoginAt   DateTime? @map("last_login_at")

  // Relations
  refreshTokens RefreshToken[]

  @@map("users")
}

model RefreshToken {
  id        String   @id @default(uuid())
  token     String   @unique @db.VarChar(512)
  userId    String   @map("user_id")
  expiresAt DateTime @map("expires_at")
  createdAt DateTime @default(now()) @map("created_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@index([expiresAt])
  @@map("refresh_tokens")
}

// ─── Enums ────────────────────────────────────────────────

enum Role {
  USER
  ADMIN
  MODERATOR
}

enum AuthProvider {
  LOCAL
  GOOGLE
}
```

### Prisma Service: src/prisma/prisma.service.ts

```typescript
import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    super({
      log: [
        { emit: 'event', level: 'query' },
        { emit: 'stdout', level: 'info' },
        { emit: 'stdout', level: 'warn' },
        { emit: 'stdout', level: 'error' },
      ],
    });
  }

  async onModuleInit() {
    await this.$connect();
    this.logger.log('Prisma connected to database');
  }

  async onModuleDestroy() {
    await this.$disconnect();
    this.logger.log('Prisma disconnected from database');
  }
}
```

---

## Auth Config: src/modules/auth/

### JWT Strategy: src/modules/auth/strategies/jwt.strategy.ts

```typescript
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy } from 'passport-jwt';
import { Request } from 'express';
import { UsersService } from '@modules/users/users.service';

// Extract JWT from HTTP-only cookie — NEVER from Authorization header for web
const cookieExtractor = (req: Request): string | null => {
  return req?.cookies?.access_token ?? null;
};

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private readonly configService: ConfigService,
    private readonly usersService: UsersService,
  ) {
    super({
      jwtFromRequest: cookieExtractor,
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('JWT_SECRET'),
    });
  }

  async validate(payload: { sub: string; email: string; role: string }) {
    const user = await this.usersService.findById(payload.sub);
    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or deactivated');
    }
    return { id: payload.sub, email: payload.email, role: payload.role };
  }
}
```

### JWT Auth Guard: src/modules/auth/guards/jwt-auth.guard.ts

```typescript
import { Injectable, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { IS_PUBLIC_KEY } from '@common/decorators/public.decorator';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private reflector: Reflector) {
    super();
  }

  canActivate(context: ExecutionContext) {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) {
      return true;
    }
    return super.canActivate(context);
  }
}
```

### Cookie Utility: src/shared/utils/cookie.util.ts

```typescript
import { Response } from 'express';

interface CookieOptions {
  domain?: string;
  secure?: boolean;
  sameSite?: 'lax' | 'strict' | 'none';
}

export function setAuthCookies(
  res: Response,
  accessToken: string,
  refreshToken: string,
  opts?: CookieOptions,
): void {
  const secure = opts?.secure ?? process.env.NODE_ENV === 'production';
  const domain = opts?.domain ?? process.env.COOKIE_DOMAIN;
  const sameSite = opts?.sameSite ?? 'lax';

  res.cookie('access_token', accessToken, {
    httpOnly: true,
    secure,
    sameSite,
    domain,
    maxAge: 30 * 60 * 1000, // 30 minutes
    path: '/',
  });

  res.cookie('refresh_token', refreshToken, {
    httpOnly: true,
    secure,
    sameSite,
    domain,
    maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
    path: '/api/v1/auth/refresh', // Only sent on refresh endpoint
  });
}

export function clearAuthCookies(res: Response): void {
  res.clearCookie('access_token', { path: '/' });
  res.clearCookie('refresh_token', { path: '/api/v1/auth/refresh' });
}
```

### Public Decorator: src/common/decorators/public.decorator.ts

```typescript
import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
```

### Current User Decorator: src/common/decorators/current-user.decorator.ts

```typescript
import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const CurrentUser = createParamDecorator(
  (data: string | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user = request.user;
    return data ? user?.[data] : user;
  },
);
```

---

## Docker

### Dockerfile (multi-stage)

```dockerfile
# ── Stage 1: Builder ──────────────────────────────────────
FROM node:22-alpine AS builder

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY prisma ./prisma
RUN npx prisma generate

COPY . .
RUN pnpm build

# Remove dev dependencies after build
RUN pnpm prune --prod

# ── Stage 2: Runner ───────────────────────────────────────
FROM node:22-alpine AS runner

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nestjs

WORKDIR /app

COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /app/prisma ./prisma
COPY --from=builder --chown=nestjs:nodejs /app/package.json ./

USER nestjs

EXPOSE 3000

ENV NODE_ENV=production

CMD ["node", "dist/main.js"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - '3000:3000'
    env_file: .env
    depends_on:
      mysql:
        condition: service_healthy
    restart: unless-stopped

  mysql:
    image: mysql:8.4
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-rootpass}
      MYSQL_DATABASE: ${DB_NAME:-myapp}
    ports:
      - '3306:3306'
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ['CMD', 'mysqladmin', 'ping', '-h', 'localhost']
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - '6379:6379'
    volumes:
      - redis_data:/data

volumes:
  mysql_data:
  redis_data:
```

---

## Commands

| Action                  | Command                                            |
|-------------------------|----------------------------------------------------|
| Start dev server        | `pnpm start:dev`                                   |
| Start debug mode        | `pnpm start:debug`                                 |
| Build production        | `pnpm build`                                       |
| Lint                    | `pnpm lint`                                        |
| Format                  | `pnpm format`                                      |
| Run unit tests          | `pnpm test`                                        |
| Run tests + coverage    | `pnpm test -- --coverage`                          |
| Run e2e tests           | `pnpm test:e2e`                                    |
| Prisma migrate (dev)    | `npx prisma migrate dev --name "description"`      |
| Prisma migrate (prod)   | `npx prisma migrate deploy`                        |
| Prisma generate client  | `npx prisma generate`                              |
| Prisma studio (GUI)     | `npx prisma studio`                                |
| Prisma reset DB         | `npx prisma migrate reset`                         |
| Generate NestJS resource | `npx nest generate resource modules/<name>`       |

---

## Verify (after scaffold)

Run these commands in order to confirm the scaffold is correct:

```bash
# 1. Install all dependencies
pnpm install

# 2. Generate Prisma client from schema
npx prisma generate

# 3. Run linter — must pass with zero errors
pnpm lint

# 4. Compile TypeScript — must succeed
pnpm build

# 5. Start dev server — verify it binds to :3000
pnpm start:dev
# Expected: "Server running on http://localhost:3000"

# 6. Smoke test health endpoint
curl http://localhost:3000/api/v1/health
# Expected: { "status": "ok" }

# 7. Verify Swagger docs load (dev only)
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/docs
# Expected: 200
```

---

## GenAI Stack (Conditional — only if PRD requires AI features)

### LLM Gateway: Vercel AI SDK

```typescript
// src/modules/ai/ai.service.ts
import { generateText, generateObject, streamText } from 'ai';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';

@Injectable()
export class AiService {
  async generate(prompt: string): Promise<string> {
    const { text } = await generateText({
      model: openai('gpt-4o'),
      prompt,
    });
    return text;
  }

  async generateStructured<T>(prompt: string, schema: z.ZodType<T>): Promise<T> {
    const { object } = await generateObject({
      model: openai('gpt-4o'),
      prompt,
      schema,
    });
    return object;
  }

  async *stream(prompt: string): AsyncGenerator<string> {
    const result = streamText({
      model: openai('gpt-4o'),
      prompt,
    });
    for await (const chunk of result.textStream) {
      yield chunk;
    }
  }
}
```

### Agentic: LangGraph.js

```typescript
// src/modules/ai/agents/research-agent.ts
import { StateGraph, Annotation } from '@langchain/langgraph';
import { ChatOpenAI } from '@langchain/openai';

const AgentState = Annotation.Root({
  messages: Annotation<BaseMessage[]>({ reducer: messagesReducer }),
  query: Annotation<string>,
  results: Annotation<string[]>({ reducer: (a, b) => [...a, ...b] }),
});

const graph = new StateGraph(AgentState)
  .addNode('search', searchNode)
  .addNode('analyze', analyzeNode)
  .addNode('respond', respondNode)
  .addEdge('__start__', 'search')
  .addEdge('search', 'analyze')
  .addEdge('analyze', 'respond')
  .addEdge('respond', '__end__')
  .compile();
```

### Vector DB: Qdrant

```typescript
// src/modules/ai/vector/qdrant.service.ts
import { QdrantClient } from '@qdrant/js-client-rest';

@Injectable()
export class QdrantService {
  private client: QdrantClient;

  constructor() {
    this.client = new QdrantClient({
      url: process.env.QDRANT_URL ?? 'http://localhost:6333',
    });
  }

  async search(collection: string, vector: number[], limit = 5) {
    return this.client.search(collection, {
      vector,
      limit,
      with_payload: true,
    });
  }

  async upsert(collection: string, points: { id: string; vector: number[]; payload: Record<string, unknown> }[]) {
    return this.client.upsert(collection, { points });
  }
}
```

### AI Observability: Langfuse

```typescript
// src/modules/ai/observability/langfuse.service.ts
import { Langfuse } from 'langfuse';

@Injectable()
export class LangfuseService implements OnModuleInit {
  private langfuse: Langfuse;

  onModuleInit() {
    this.langfuse = new Langfuse({
      publicKey: process.env.LANGFUSE_PUBLIC_KEY!,
      secretKey: process.env.LANGFUSE_SECRET_KEY!,
      baseUrl: process.env.LANGFUSE_BASE_URL ?? 'https://cloud.langfuse.com',
    });
  }

  createTrace(name: string, metadata?: Record<string, unknown>) {
    return this.langfuse.trace({ name, metadata });
  }
}
```

### Structured Output: Zod + Vercel AI SDK

```typescript
// Example: Extract product review with validated schema
import { generateObject } from 'ai';
import { openai } from '@ai-sdk/openai';
import { z } from 'zod';

const ReviewSchema = z.object({
  sentiment: z.enum(['positive', 'negative', 'neutral']),
  score: z.number().min(0).max(1),
  keyPoints: z.array(z.string()),
  summary: z.string(),
});

type Review = z.infer<typeof ReviewSchema>;

async function extractReview(text: string): Promise<Review> {
  const { object } = await generateObject({
    model: openai('gpt-4o'),
    prompt: `Analyze this review:\n${text}`,
    schema: ReviewSchema,
  });
  return object;
}
```

---

## Auth Rules (HARD — same as Alpha AI standard)

These rules are non-negotiable regardless of language:

| Rule                          | Value                                          |
|-------------------------------|-------------------------------------------------|
| Token storage                 | HTTP-Only cookies ONLY                          |
| NEVER use                     | localStorage, sessionStorage, Authorization header (web) |
| Access token expiry            | 30 minutes                                      |
| Refresh token expiry           | 7 days                                          |
| CSRF protection               | Double-submit cookie pattern                    |
| Logout                        | Blacklist refresh token in DB, clear cookies    |
| Google OAuth2                 | Server-side Authorization Code Grant            |
| All login methods              | End with setting JWT cookies (same flow)        |
| Password hashing              | bcryptjs with salt rounds >= 12                 |
| Refresh token rotation        | Issue new refresh token on each refresh         |
| Refresh cookie path            | Scoped to `/api/v1/auth/refresh` only           |

---

## Error Handling Pattern

```typescript
// src/common/filters/all-exceptions.filter.ts
import {
  ExceptionFilter, Catch, ArgumentsHost,
  HttpException, HttpStatus, Logger,
} from '@nestjs/common';
import { Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();
      message = typeof res === 'string' ? res : (res as any).message ?? message;
    }

    if (status >= 500) {
      this.logger.error(`${status} — ${message}`, (exception as Error).stack);
    }

    response.status(status).json({
      statusCode: status,
      message,
      timestamp: new Date().toISOString(),
    });
  }
}
```

---

## Testing Patterns

### Unit Test (Service)

```typescript
// src/modules/users/users.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from './users.service';
import { UsersRepository } from './users.repository';

describe('UsersService', () => {
  let service: UsersService;
  let repository: jest.Mocked<UsersRepository>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: UsersRepository,
          useValue: {
            findById: jest.fn(),
            create: jest.fn(),
            update: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get(UsersService);
    repository = module.get(UsersRepository);
  });

  it('should return user by id', async () => {
    const mockUser = { id: '1', email: 'test@test.com', displayName: 'Test' };
    repository.findById.mockResolvedValue(mockUser as any);

    const result = await service.findById('1');
    expect(result).toEqual(mockUser);
    expect(repository.findById).toHaveBeenCalledWith('1');
  });
});
```

### E2E Test

```typescript
// test/app.e2e-spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import * as cookieParser from 'cookie-parser';
import { AppModule } from '../src/app.module';

describe('Auth (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.use(cookieParser());
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('/api/v1/health (GET) — returns ok', () => {
    return request(app.getHttpServer())
      .get('/api/v1/health')
      .expect(200)
      .expect({ status: 'ok' });
  });

  it('/api/v1/auth/register (POST) — creates user and sets cookies', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email: 'new@test.com', password: 'StrongP@ss1', displayName: 'Test' })
      .expect(201);

    const cookies = res.headers['set-cookie'];
    expect(cookies).toBeDefined();
    expect(cookies.some((c: string) => c.startsWith('access_token='))).toBe(true);
    expect(cookies.some((c: string) => c.includes('HttpOnly'))).toBe(true);
  });
});
```

---

## Script Definitions (package.json scripts)

```json
{
  "scripts": {
    "build": "nest build",
    "format": "prettier --write \"src/**/*.ts\" \"test/**/*.ts\"",
    "start": "nest start",
    "start:dev": "nest start --watch",
    "start:debug": "nest start --debug --watch",
    "start:prod": "node dist/main",
    "lint": "eslint \"{src,apps,libs,test}/**/*.ts\" --fix",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:cov": "jest --coverage",
    "test:debug": "node --inspect-brk -r tsconfig-paths/register -r ts-node/register node_modules/.bin/jest --runInBand",
    "test:e2e": "jest --config ./test/jest-e2e.json",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev",
    "prisma:studio": "prisma studio",
    "prisma:reset": "prisma migrate reset",
    "docker:build": "docker build -t myapp .",
    "docker:up": "docker compose up -d",
    "docker:down": "docker compose down"
  }
}
```
