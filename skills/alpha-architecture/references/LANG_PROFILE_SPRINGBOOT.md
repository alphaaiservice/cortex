# Language Profile: Java / Spring Boot

> Used by auto-build, init-project, and SKILL.md when backend_language = java-springboot

---

## Runtime

- Language: Java 21 (LTS)
- Framework: Spring Boot 3.4.x (Spring Framework 6.2.x)
- Build Tool: Gradle (Kotlin DSL) -- `build.gradle.kts`
- Alternative Build: Maven (`pom.xml`) if user explicitly prefers
- Server: Embedded Tomcat (default), Netty for reactive
- Packaging: Executable JAR via `bootJar` task
- Min JDK: 21 (required by Spring Framework 6.2)

---

## Directory Structure

```
src/
  main/
    java/com/alphaai/{appname}/
      {AppName}Application.java            # @SpringBootApplication entry point
      config/
        SecurityConfig.java                 # SecurityFilterChain, CORS, CSRF
        WebConfig.java                      # WebMvcConfigurer (interceptors, formatters)
        CorsConfig.java                     # Global CORS configuration
        SwaggerConfig.java                  # springdoc-openapi GroupedOpenApi beans
        RedisConfig.java                    # RedisTemplate, cache manager
        AsyncConfig.java                    # @EnableAsync, thread pool executor
      controller/
        AuthController.java                 # /api/auth/** (login, register, refresh, logout)
        UserController.java                 # /api/users/** (CRUD, profile)
        AdminController.java               # /api/admin/** (admin-only endpoints)
      service/
        AuthService.java                    # Login, register, token refresh logic
        UserService.java                    # User business logic
        EmailService.java                   # Thymeleaf + JavaMailSender
      repository/
        UserRepository.java                 # extends JpaRepository<User, Long>
        RoleRepository.java                 # extends JpaRepository<Role, Long>
        TokenBlacklistRepository.java       # Redis-backed token blacklist
      model/
        User.java                           # @Entity, JPA mapped
        Role.java                           # @Entity, enum or table
        AuditableEntity.java               # @MappedSuperclass (createdAt, updatedAt)
      dto/
        request/
          LoginRequest.java                 # @Valid annotated
          RegisterRequest.java
          CreateUserRequest.java
        response/
          UserResponse.java                 # Java record
          AuthResponse.java
          PagedResponse.java                # Generic wrapper for paginated results
      security/
        JwtProvider.java                    # Token generation, validation, extraction
        JwtAuthFilter.java                  # OncePerRequestFilter reading JWT from cookie
        CookieUtils.java                    # HTTP-only cookie builder (access + refresh)
        CustomUserDetailsService.java       # implements UserDetailsService
      exception/
        GlobalExceptionHandler.java         # @RestControllerAdvice
        NotFoundException.java              # extends RuntimeException
        BadRequestException.java
        AppException.java                   # Generic application exception
        ErrorResponse.java                  # Standard error DTO (timestamp, status, message, path)
      mapper/
        UserMapper.java                     # @Mapper(componentModel = "spring") MapStruct
    resources/
      application.yml                       # Main config (spring.profiles.active: dev)
      application-dev.yml                   # Dev overrides (debug logging, DDL auto)
      application-prod.yml                  # Prod overrides (connection pools, log levels)
      db/
        migration/
          V1__create_users_table.sql        # Flyway baseline migration
          V2__create_roles_table.sql
          V3__add_user_roles_join.sql
      templates/
        emails/
          welcome.html                      # Thymeleaf email template
          password-reset.html
  test/
    java/com/alphaai/{appname}/
      controller/
        AuthControllerTest.java             # @WebMvcTest + MockMvc
        UserControllerTest.java
      service/
        AuthServiceTest.java                # @ExtendWith(MockitoExtension.class)
        UserServiceTest.java
      repository/
        UserRepositoryTest.java             # @DataJpaTest
      integration/
        AuthIntegrationTest.java            # @SpringBootTest + Testcontainers
    resources/
      application-test.yml                  # H2 in-memory for unit tests
```

---

## Core Dependencies (build.gradle.kts)

```kotlin
plugins {
    java
    id("org.springframework.boot") version "3.4.1"
    id("io.spring.dependency-management") version "1.1.7"
    id("checkstyle")
}

group = "com.alphaai"
version = "0.0.1-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

configurations {
    compileOnly {
        extendsFrom(configurations.annotationProcessor.get())
    }
}

repositories {
    mavenCentral()
}

val jjwtVersion = "0.12.6"
val mapstructVersion = "1.6.3"

dependencies {
    // --- Core Spring Boot ---
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-actuator")

    // --- Database ---
    runtimeOnly("com.mysql:mysql-connector-j")

    // --- Flyway ---
    implementation("org.flywaydb:flyway-core")
    implementation("org.flywaydb:flyway-mysql")

    // --- JWT (jjwt 0.12.x) ---
    implementation("io.jsonwebtoken:jjwt-api:$jjwtVersion")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:$jjwtVersion")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:$jjwtVersion")

    // --- Lombok ---
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")

    // --- MapStruct ---
    implementation("org.mapstruct:mapstruct:$mapstructVersion")
    annotationProcessor("org.mapstruct:mapstruct-processor:$mapstructVersion")

    // --- API Documentation ---
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.3")

    // --- Dev Tools ---
    developmentOnly("org.springframework.boot:spring-boot-devtools")

    // --- Test ---
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
    testRuntimeOnly("com.h2database:h2")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

// MapStruct + Lombok interop: Lombok must run before MapStruct
tasks.withType<JavaCompile> {
    options.compilerArgs.addAll(listOf(
        "-Amapstruct.defaultComponentModel=spring",
        "-Amapstruct.unmappedTargetPolicy=IGNORE"
    ))
}

tasks.withType<Test> {
    useJUnitPlatform()
}

checkstyle {
    toolVersion = "10.21.1"
    configFile = file("checkstyle.xml")
}
```

**settings.gradle.kts:**

```kotlin
rootProject.name = "{appname}"
```

---

## Conditional Dependencies

Add to `build.gradle.kts` based on PRD requirements:

| Feature | Dependency | Notes |
|---------|-----------|-------|
| MongoDB | `spring-boot-starter-data-mongodb` | Use alongside or instead of JPA |
| Redis | `spring-boot-starter-data-redis` | Default Lettuce client |
| Email | `spring-boot-starter-mail` + `spring-boot-starter-thymeleaf` | HTML templates via Thymeleaf |
| Queue (RabbitMQ) | `spring-boot-starter-amqp` | `@RabbitListener` consumers |
| Queue (Simple) | Built-in `@Async` + `@Scheduled` | No external broker needed |
| File Upload (S3) | `software.amazon.awssdk:s3:2.29.x` | AWS SDK v2 |
| Search (Meilisearch) | `com.meilisearch.sdk:meilisearch-java:0.14.x` | Full-text search |
| WebSocket | `spring-boot-starter-websocket` | STOMP over SockJS |
| Push (FCM) | `com.google.firebase:firebase-admin:9.4.x` | Firebase Cloud Messaging |
| Error Tracking | `io.sentry:sentry-spring-boot-starter-jakarta:7.x` | Auto-captures exceptions |
| Analytics | `com.posthog.java:posthog:1.x` | PostHog event tracking |
| 2FA/TOTP | `dev.samstevens.totp:totp:1.7.x` | TOTP generation + verification |
| GenAI (Spring AI) | `org.springframework.ai:spring-ai-openai-spring-boot-starter` | Spring AI 1.0.x |
| GenAI (LangChain4j) | `dev.langchain4j:langchain4j-spring-boot-starter:1.0.x` | Alternative AI framework |
| Testcontainers | `org.testcontainers:mysql:1.20.x` + `spring-boot-testcontainers` | Integration tests |

---

## Dev Dependencies

```kotlin
// Already included in Core Dependencies above
testImplementation("org.springframework.boot:spring-boot-starter-test")  // JUnit 5, Mockito, AssertJ
testImplementation("org.springframework.security:spring-security-test")  // @WithMockUser, SecurityMockMvc
testRuntimeOnly("com.h2database:h2")                                    // In-memory DB for tests

// Optional: Testcontainers for integration tests
testImplementation("org.springframework.boot:spring-boot-testcontainers")
testImplementation("org.testcontainers:mysql:1.20.4")
testImplementation("org.testcontainers:junit-jupiter:1.20.4")
```

---

## Config Files

| File | Purpose |
|------|---------|
| `build.gradle.kts` | Gradle Kotlin DSL build config |
| `settings.gradle.kts` | Project name and multi-module settings |
| `application.yml` | Main config with profile activation |
| `application-dev.yml` | Dev overrides (debug logging, DDL auto) |
| `application-prod.yml` | Prod overrides (pool sizes, log levels) |
| `.env.example` | Environment variable template for Docker Compose |
| `checkstyle.xml` | Google Java Style config |
| `lombok.config` | Lombok global settings |
| `Dockerfile` | Multi-stage build |
| `docker-compose.yml` | Local dev stack (MySQL, Redis) |

**lombok.config** (project root):

```
config.stopBubbling = true
lombok.addLombokGeneratedAnnotation = true
```

---

## Entry Point (Application.java)

```java
package com.alphaai.myapp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableJpaAuditing
@EnableAsync
public class MyAppApplication {

    public static void main(String[] args) {
        SpringApplication.run(MyAppApplication.class, args);
    }
}
```

---

## Database Config (application.yml)

```yaml
spring:
  profiles:
    active: dev

  datasource:
    url: jdbc:mysql://${DB_HOST:localhost}:${DB_PORT:3306}/${DB_NAME:myapp}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
    username: ${DB_USERNAME:root}
    password: ${DB_PASSWORD:secret}
    driver-class-name: com.mysql.cj.jdbc.Driver
    hikari:
      maximum-pool-size: ${DB_POOL_SIZE:10}
      minimum-idle: 5
      idle-timeout: 300000
      connection-timeout: 20000
      max-lifetime: 1200000

  jpa:
    hibernate:
      ddl-auto: validate       # NEVER auto in prod; Flyway handles DDL
    show-sql: false
    open-in-view: false         # Disable OSIV to prevent lazy-loading leaks
    properties:
      hibernate:
        dialect: org.hibernate.dialect.MySQLDialect
        format_sql: true
        default_batch_fetch_size: 20
        jdbc:
          batch_size: 30
        order_inserts: true
        order_updates: true

  flyway:
    enabled: true
    baseline-on-migrate: true
    locations: classpath:db/migration
    validate-on-migrate: true

server:
  port: ${SERVER_PORT:8080}
  servlet:
    context-path: /api
  error:
    include-message: always
    include-binding-errors: always

# --- JWT Configuration ---
app:
  jwt:
    secret: ${JWT_SECRET:your-256-bit-secret-key-change-in-production-minimum-32-chars}
    access-token-expiration-ms: 1800000    # 30 minutes
    refresh-token-expiration-ms: 604800000  # 7 days
    cookie:
      access-token-name: access_token
      refresh-token-name: refresh_token
      domain: ${COOKIE_DOMAIN:localhost}
      secure: ${COOKIE_SECURE:false}
      same-site: Lax

# --- Actuator ---
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized

# --- Logging ---
logging:
  level:
    root: INFO
    com.alphaai: DEBUG
    org.springframework.security: DEBUG
    org.hibernate.SQL: DEBUG
    org.hibernate.type.descriptor.sql.BasicBinder: TRACE
```

**application-dev.yml:**

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: update          # Auto-DDL in dev only
    show-sql: true

logging:
  level:
    root: INFO
    com.alphaai: DEBUG
```

**application-prod.yml:**

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 30
      minimum-idle: 10
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false

app:
  jwt:
    cookie:
      secure: true
      same-site: Strict

logging:
  level:
    root: WARN
    com.alphaai: INFO
    org.springframework.security: WARN
```

---

## Auth Config (security/)

### SecurityConfig.java

```java
package com.alphaai.myapp.security;

// NOTE: This file intentionally kept under ~120 lines.
// Extracted components: JwtAuthFilter, JwtProvider, CookieUtils, CustomUserDetailsService

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;
    private final CustomUserDetailsService userDetailsService;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter,
                          CustomUserDetailsService userDetailsService) {
        this.jwtAuthFilter = jwtAuthFilter;
        this.userDetailsService = userDetailsService;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)      // Stateless JWT -- CSRF via double-submit cookie
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(
                    "/auth/login",
                    "/auth/register",
                    "/auth/refresh",
                    "/auth/forgot-password",
                    "/auth/reset-password"
                ).permitAll()
                .requestMatchers(
                    "/swagger-ui/**",
                    "/v3/api-docs/**",
                    "/actuator/health"
                ).permitAll()
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers("/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .authenticationProvider(authenticationProvider())
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public AuthenticationProvider authenticationProvider() {
        DaoAuthenticationProvider provider = new DaoAuthenticationProvider();
        provider.setUserDetailsService(userDetailsService);
        provider.setPasswordEncoder(passwordEncoder());
        return provider;
    }

    @Bean
    public AuthenticationManager authenticationManager(
            AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
}
```

### JwtProvider.java

```java
package com.alphaai.myapp.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Date;
import java.util.Map;
import java.util.function.Function;

@Component
public class JwtProvider {

    private static final Logger log = LoggerFactory.getLogger(JwtProvider.class);

    @Value("${app.jwt.secret}")
    private String jwtSecret;

    @Value("${app.jwt.access-token-expiration-ms}")
    private long accessTokenExpirationMs;

    @Value("${app.jwt.refresh-token-expiration-ms}")
    private long refreshTokenExpirationMs;

    public String generateAccessToken(UserDetails userDetails) {
        return buildToken(Map.of("type", "access"), userDetails, accessTokenExpirationMs);
    }

    public String generateRefreshToken(UserDetails userDetails) {
        return buildToken(Map.of("type", "refresh"), userDetails, refreshTokenExpirationMs);
    }

    private String buildToken(Map<String, Object> extraClaims,
                              UserDetails userDetails,
                              long expirationMs) {
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .claims(extraClaims)
                .subject(userDetails.getUsername())
                .issuedAt(new Date(now))
                .expiration(new Date(now + expirationMs))
                .signWith(getSigningKey(), Jwts.SIG.HS256)
                .compact();
    }

    public String extractUsername(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    public boolean isTokenValid(String token, UserDetails userDetails) {
        try {
            String username = extractUsername(token);
            return username.equals(userDetails.getUsername()) && !isTokenExpired(token);
        } catch (ExpiredJwtException e) {
            log.debug("JWT expired: {}", e.getMessage());
            return false;
        } catch (JwtException e) {
            log.warn("Invalid JWT: {}", e.getMessage());
            return false;
        }
    }

    private boolean isTokenExpired(String token) {
        return extractExpiration(token).before(new Date());
    }

    private Date extractExpiration(String token) {
        return extractClaim(token, Claims::getExpiration);
    }

    private <T> T extractClaim(String token, Function<Claims, T> resolver) {
        Claims claims = Jwts.parser()
                .verifyWith(getSigningKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return resolver.apply(claims);
    }

    private SecretKey getSigningKey() {
        byte[] keyBytes = Decoders.BASE64.decode(jwtSecret);
        return Keys.hmacShaKeyFor(keyBytes);
    }
}
```

### JwtAuthFilter.java

```java
package com.alphaai.myapp.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Arrays;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtProvider jwtProvider;
    private final CustomUserDetailsService userDetailsService;

    @Value("${app.jwt.cookie.access-token-name}")
    private String accessTokenCookieName;

    public JwtAuthFilter(JwtProvider jwtProvider,
                         CustomUserDetailsService userDetailsService) {
        this.jwtProvider = jwtProvider;
        this.userDetailsService = userDetailsService;
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain)
            throws ServletException, IOException {

        // Extract JWT from HTTP-only cookie (NEVER from Authorization header / localStorage)
        String jwt = extractTokenFromCookie(request);

        if (jwt != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            String username = jwtProvider.extractUsername(jwt);

            if (username != null) {
                UserDetails userDetails = userDetailsService.loadUserByUsername(username);

                if (jwtProvider.isTokenValid(jwt, userDetails)) {
                    UsernamePasswordAuthenticationToken authToken =
                        new UsernamePasswordAuthenticationToken(
                            userDetails, null, userDetails.getAuthorities());
                    authToken.setDetails(
                        new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authToken);
                }
            }
        }

        filterChain.doFilter(request, response);
    }

    private String extractTokenFromCookie(HttpServletRequest request) {
        if (request.getCookies() == null) {
            return null;
        }
        return Arrays.stream(request.getCookies())
                .filter(cookie -> accessTokenCookieName.equals(cookie.getName()))
                .map(Cookie::getValue)
                .findFirst()
                .orElse(null);
    }
}
```

### CookieUtils.java

```java
package com.alphaai.myapp.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseCookie;
import org.springframework.stereotype.Component;

@Component
public class CookieUtils {

    @Value("${app.jwt.access-token-expiration-ms}")
    private long accessTokenExpirationMs;

    @Value("${app.jwt.refresh-token-expiration-ms}")
    private long refreshTokenExpirationMs;

    @Value("${app.jwt.cookie.access-token-name}")
    private String accessTokenName;

    @Value("${app.jwt.cookie.refresh-token-name}")
    private String refreshTokenName;

    @Value("${app.jwt.cookie.domain}")
    private String domain;

    @Value("${app.jwt.cookie.secure}")
    private boolean secure;

    @Value("${app.jwt.cookie.same-site}")
    private String sameSite;

    public ResponseCookie createAccessTokenCookie(String token) {
        return buildCookie(accessTokenName, token, accessTokenExpirationMs / 1000);
    }

    public ResponseCookie createRefreshTokenCookie(String token) {
        return buildCookie(refreshTokenName, token, refreshTokenExpirationMs / 1000);
    }

    public ResponseCookie deleteAccessTokenCookie() {
        return buildCookie(accessTokenName, "", 0);
    }

    public ResponseCookie deleteRefreshTokenCookie() {
        return buildCookie(refreshTokenName, "", 0);
    }

    private ResponseCookie buildCookie(String name, String value, long maxAgeSec) {
        return ResponseCookie.from(name, value)
                .httpOnly(true)           // MANDATORY: prevents XSS access
                .secure(secure)           // true in prod (HTTPS only)
                .path("/api")
                .domain(domain)
                .maxAge(maxAgeSec)
                .sameSite(sameSite)
                .build();
    }
}
```

---

## Docker

**Dockerfile (multi-stage build):**

```dockerfile
# --- Stage 1: Build ---
FROM gradle:8.12-jdk21 AS build
WORKDIR /app
COPY build.gradle.kts settings.gradle.kts ./
COPY gradle ./gradle
RUN gradle dependencies --no-daemon || true
COPY src ./src
RUN gradle bootJar --no-daemon -x test

# --- Stage 2: Run ---
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=build /app/build/libs/*.jar app.jar
RUN chown appuser:appgroup app.jar

USER appuser
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:8080/api/actuator/health || exit 1

ENTRYPOINT ["java", "-XX:+UseZGC", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
```

---

## Commands

| Action | Command |
|--------|---------|
| Start dev | `./gradlew bootRun` |
| Build | `./gradlew build` |
| Build JAR only | `./gradlew bootJar` |
| Test | `./gradlew test` |
| Lint | `./gradlew checkstyleMain checkstyleTest` |
| Format | google-java-format via IDE or `./gradlew spotlessApply` (if Spotless plugin added) |
| Migrate | Flyway auto-runs on startup (`spring.flyway.enabled=true`) |
| New migration | Create `src/main/resources/db/migration/V{n}__{description}.sql` |
| Clean | `./gradlew clean` |
| Dependency report | `./gradlew dependencies` |

---

## Verify (after scaffold)

```bash
# 1. Compile and run all checks
./gradlew build

# 2. Start the application (verify it boots on :8080)
./gradlew bootRun
# Expected: "Started MyAppApplication in X seconds"
# Health check: curl http://localhost:8080/api/actuator/health

# 3. Run tests
./gradlew test

# 4. Verify Swagger UI loads
# Open: http://localhost:8080/api/swagger-ui/index.html
```

---

## GenAI Stack

| Component | Technology | Dependency |
|-----------|-----------|------------|
| LLM Gateway | Spring AI 1.0.x | `spring-ai-openai-spring-boot-starter` |
| Alternative LLM | LangChain4j 1.0.x | `langchain4j-spring-boot-starter` |
| Agentic | LangChain4j Agents + Tools | `langchain4j` with `@Tool` annotated methods |
| Vector DB | Qdrant | `io.qdrant:client:1.12.x` |
| Embeddings | Spring AI EmbeddingModel | `spring-ai-openai-spring-boot-starter` |
| Observability | Langfuse | `langfuse-java` or HTTP REST integration |
| Structured Output | Spring AI | Java records + `BeanOutputConverter` |
| RAG | Spring AI Advisors | `QuestionAnswerAdvisor` + Qdrant `VectorStore` |

**Spring AI configuration (application.yml):**

```yaml
spring:
  ai:
    openai:
      api-key: ${OPENAI_API_KEY}
      chat:
        options:
          model: gpt-4o
          temperature: 0.7
      embedding:
        options:
          model: text-embedding-3-large
```

**LangChain4j configuration (application.yml):**

```yaml
langchain4j:
  open-ai:
    chat-model:
      api-key: ${OPENAI_API_KEY}
      model-name: gpt-4o
      temperature: 0.7
      log-requests: true
      log-responses: true
```

---

## Layer Segregation Rules (Spring Boot)

```
controller/ --> service/ --> repository/ --> model/ + db/
  NEVER: controller/ imports repository/ directly
  NEVER: service/ imports controller/
  NEVER: repository/ imports service/
  NEVER: business logic in controller/ (thin @RestController only)
  NEVER: DB queries in service/ (use repository/)
  NEVER: HTTP concerns in service/ (no HttpServletRequest/Response)
```

---

## Auth Rules (HARD -- same as Alpha AI core)

- JWT stored in HTTP-Only cookies ONLY
- NEVER localStorage or sessionStorage for tokens
- Access token: 30 min expiry
- Refresh token: 7 days expiry
- CSRF: Double-submit cookie pattern (or disabled for pure API with SameSite=Strict)
- Logout: Blacklist tokens in Redis (TTL = remaining token lifetime)
- Google OAuth2: Server-side Authorization Code Grant
- All login methods end by setting JWT cookies (consistent flow)
- Password hashing: BCrypt with strength 12

---

## Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Package | lowercase, dot-separated | `com.alphaai.myapp.controller` |
| Class | PascalCase | `UserController`, `AuthService` |
| Method | camelCase | `findByEmail()`, `createUser()` |
| Constant | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| DB table | snake_case, plural | `users`, `user_roles` |
| DB column | snake_case | `created_at`, `email_verified` |
| REST endpoint | kebab-case, plural nouns | `/api/users`, `/api/auth/forgot-password` |
| DTO | PascalCase + suffix | `CreateUserRequest`, `UserResponse` |
| Config property | kebab-case | `app.jwt.access-token-expiration-ms` |
| Migration file | `V{n}__{description}.sql` | `V1__create_users_table.sql` |
| Test class | `{ClassName}Test` | `AuthServiceTest` |

---

## Key Annotations Reference

| Annotation | Layer | Purpose |
|-----------|-------|---------|
| `@RestController` | controller | REST endpoints, auto `@ResponseBody` |
| `@RequestMapping` | controller | Base path for controller |
| `@Valid` | controller | Trigger Jakarta validation on `@RequestBody` |
| `@PreAuthorize` | controller | Method-level RBAC (`@EnableMethodSecurity`) |
| `@Service` | service | Business logic bean |
| `@Transactional` | service | Declarative transaction management |
| `@Repository` | repository | Data access, exception translation |
| `@Entity` | model | JPA entity mapping |
| `@MappedSuperclass` | model | Shared fields (audit timestamps) |
| `@Mapper` | mapper | MapStruct interface-to-impl generation |
| `@Component` | security | Generic Spring bean (filters, providers) |
| `@Configuration` | config | Spring configuration class |
| `@RestControllerAdvice` | exception | Global exception handler |
