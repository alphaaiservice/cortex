---
description: "Auto-generate API documentation from codebase. Creates OpenAPI spec, endpoint docs, and Postman collection."
---

# API Documentation Generator

Generate comprehensive API documentation for this project.

## Step 1: Discover API Endpoints

Scan for route definitions:
- Express/Fastify: `router.get/post/put/delete`, `app.get/post`
- FastAPI: `@app.get/post`, `@router.get/post`
- Django: `urlpatterns`, `@api_view`
- NestJS: `@Get/@Post/@Put/@Delete`
- Spring: `@GetMapping/@PostMapping`

For each endpoint, extract:
- HTTP method and path
- Request parameters (path, query, body)
- Request/response types
- Authentication requirements
- Middleware applied
- Error responses

## Step 2: Generate OpenAPI Spec

Create `docs/openapi.yaml` with:
- API info and server URLs
- Authentication schemes
- All endpoints with full schemas
- Request/response examples
- Error response schemas

## Step 3: Generate Markdown Docs

Create `docs/API.md`:

```markdown
# API Documentation

## Authentication
[Auth mechanism description]

## Endpoints

### [Group Name]

#### `METHOD /path`
**Description**: [what it does]

**Parameters**:
| Name | In | Type | Required | Description |
|------|------|------|----------|-------------|

**Request Body**:
```json
{ "example": "body" }
```

**Response** (200):
```json
{ "example": "response" }
```

**Errors**:
| Code | Description |
|------|-------------|
```

## Step 4: Generate Postman Collection

Create `docs/postman_collection.json` with:
- All endpoints organized by group
- Pre-configured request bodies
- Environment variable placeholders
- Example responses

## Output

1. `docs/openapi.yaml` — OpenAPI 3.0 specification
2. `docs/API.md` — Human-readable API docs
3. `docs/postman_collection.json` — Importable Postman collection
