# CODE_PATTERNS_SPRINGBOOT.md — Java/Spring Boot Code Patterns

> **Language**: Java/Spring Boot | See also: [Python/FastAPI](CODE_PATTERNS_PYTHON.md) · [Node.js/NestJS](CODE_PATTERNS_NESTJS.md)
>
> Load this file on demand when writing Java/Spring Boot backend code.

---

## 1. Layer Segregation Patterns

### Controller Layer — `controller/` (Thin @RestController ONLY)

```java
// ✅ CORRECT: Thin controller — delegates everything to service
@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    // Constructor injection (NEVER field injection)
    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping("/{userId}")
    public ResponseEntity<UserResponse> getUser(@PathVariable Long userId) {
        return ResponseEntity.ok(userService.getById(userId));
    }

    @PostMapping
    public ResponseEntity<UserResponse> createUser(@Valid @RequestBody CreateUserRequest request) {
        UserResponse created = userService.create(request);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}").buildAndExpand(created.id()).toUri();
        return ResponseEntity.created(location).body(created);
    }

    @GetMapping
    public ResponseEntity<PagedResponse<UserResponse>> listUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(userService.listUsers(page, size));
    }
}
```

```java
// ❌ WRONG: Business logic in controller — direct repository access
@RestController
@RequestMapping("/api/users")
public class UserController {

    @Autowired  // ❌ Field injection — use constructor injection
    private UserRepository userRepository;

    @GetMapping("/{userId}")
    public ResponseEntity<User> getUser(@PathVariable Long userId) {
        // ❌ Direct repository call in controller
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Not found"));
        // ❌ Business logic in controller
        if (!user.isActive()) {
            throw new RuntimeException("User is inactive");
        }
        return ResponseEntity.ok(user);  // ❌ Returning entity, not DTO
    }
}
```

### Service Layer — `service/` (Business Logic ONLY)

```java
// ✅ CORRECT: Service uses repository, contains business logic, returns DTOs
@Service
public class UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository,
                       UserMapper userMapper,
                       PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.userMapper = userMapper;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional(readOnly = true)
    public UserResponse getById(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new NotFoundException("User not found with id: " + userId));
        return userMapper.toResponse(user);
    }

    @Transactional
    public UserResponse create(CreateUserRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new ConflictException("Email already registered");
        }
        User user = userMapper.toEntity(request);
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        User saved = userRepository.save(user);
        return userMapper.toResponse(saved);
    }

    @Transactional(readOnly = true)
    public PagedResponse<UserResponse> listUsers(int page, int size) {
        Page<User> users = userRepository.findAll(
                PageRequest.of(page, size, Sort.by("createdAt").descending()));
        List<UserResponse> content = users.getContent().stream()
                .map(userMapper::toResponse).toList();
        return new PagedResponse<>(content, users.getNumber(), users.getSize(),
                users.getTotalElements(), users.getTotalPages());
    }
}
```

```java
// ❌ WRONG: Service with direct DB access — no repository abstraction
@Service
public class UserService {

    @PersistenceContext
    private EntityManager entityManager;  // ❌ Direct EntityManager in service

    public User getById(Long userId) {
        // ❌ Raw JPQL in service layer — use repository
        return entityManager.createQuery("SELECT u FROM User u WHERE u.id = :id", User.class)
                .setParameter("id", userId)
                .getSingleResult();
    }
}
```

### Repository Layer — `repository/` (Data Access ONLY)

```java
// ✅ CORRECT: Spring Data JPA repository — pure data access
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    @Query("SELECT u FROM User u JOIN u.roles r WHERE r.name = :roleName")
    List<User> findByRoleName(@Param("roleName") String roleName);

    @Query("SELECT u FROM User u WHERE u.lastLoginAt < :cutoff AND u.active = true")
    Page<User> findInactiveUsers(@Param("cutoff") Instant cutoff, Pageable pageable);
}
```

```java
// ❌ WRONG: Business logic in repository
public interface UserRepository extends JpaRepository<User, Long> {

    // ❌ Complex business filtering belongs in service layer
    @Query("""
        SELECT u FROM User u WHERE u.active = true
        AND u.subscription = 'PREMIUM' AND u.lastLoginAt > :thirtyDaysAgo
        AND u.totalOrders > 10 ORDER BY u.loyaltyPoints DESC
    """)
    List<User> findActivePremiumLoyalCustomers(@Param("thirtyDaysAgo") Instant cutoff);
}
```

### DTO Layer — `dto/` (Java Records)

```java
// ✅ CORRECT: DTOs as Java records with Jakarta validation
// dto/request/CreateUserRequest.java
public record CreateUserRequest(
        @NotBlank(message = "Name is required")
        @Size(min = 2, max = 100)
        String name,

        @NotBlank(message = "Email is required")
        @Email(message = "Invalid email format")
        String email,

        @NotBlank(message = "Password is required")
        @Size(min = 8, max = 128, message = "Password must be 8-128 characters")
        String password
) {}

// dto/response/UserResponse.java
public record UserResponse(
        Long id, String name, String email, String avatarUrl, Instant createdAt
) {}

// dto/response/PagedResponse.java
public record PagedResponse<T>(
        List<T> content, int page, int size, long totalElements, int totalPages
) {}
```

```java
// ❌ WRONG: Using entity classes as API response
@PostMapping
public ResponseEntity<User> createUser(@RequestBody User user) {
    // ❌ Exposes entity directly — leaks password hash, internal fields
    return ResponseEntity.ok(userRepository.save(user));
}
```

---

## 2. Auth Implementation — Spring Security + JWT + HTTP-Only Cookies

```
# ┌─────────────────────────────────────────────────────────────────┐
# │  HARD RULE: ALL auth verification happens in SecurityFilterChain│
# │  + JwtAuthFilter MIDDLEWARE — NEVER in controllers.            │
# │  ❌ NEVER: @PreAuthorize("isAuthenticated()") — redundant     │
# │  ❌ NEVER: manual token/auth checks in controller methods      │
# │  ✅ ALWAYS: SecurityFilterChain.authorizeHttpRequests() for    │
# │     path-based auth (permitAll, hasRole, authenticated)        │
# │  ✅ ALWAYS: JwtAuthFilter extracts JWT, sets SecurityContext   │
# │  ✅ OK: @PreAuthorize("hasPermission('x')") for granular RBAC │
# │     (evaluated by Spring AOP — still middleware-layer)         │
# └─────────────────────────────────────────────────────────────────┘
```

```java
// ✅ CORRECT: SecurityFilterChain with stateless JWT from cookies
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

    // SINGLE SOURCE OF TRUTH for authentication.
    // ALL path-based auth rules go HERE — never in controllers.
    // Controllers are thin — they just call services.
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(session ->
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(
                    "/api/auth/login", "/api/auth/register",
                    "/api/auth/refresh", "/api/auth/google",
                    "/api/auth/google/callback",
                    "/.well-known/agent.json"
                ).permitAll()
                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
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

```java
// ✅ CORRECT: JWT filter extracts token from HTTP-only cookie
@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtProvider jwtProvider;
    private final CustomUserDetailsService userDetailsService;
    private final RedisTemplate<String, String> redisTemplate;

    @Value("${app.jwt.cookie.access-token-name}")
    private String accessTokenCookieName;

    public JwtAuthFilter(JwtProvider jwtProvider,
                         CustomUserDetailsService userDetailsService,
                         RedisTemplate<String, String> redisTemplate) {
        this.jwtProvider = jwtProvider;
        this.userDetailsService = userDetailsService;
        this.redisTemplate = redisTemplate;
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain)
            throws ServletException, IOException {

        String jwt = extractTokenFromCookie(request);

        if (jwt != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            // Check token blacklist (logout support)
            if (Boolean.TRUE.equals(redisTemplate.hasKey("blacklist:" + jwt))) {
                filterChain.doFilter(request, response);
                return;
            }
            String username = jwtProvider.extractUsername(jwt);
            if (username != null) {
                UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                if (jwtProvider.isTokenValid(jwt, userDetails)) {
                    var authToken = new UsernamePasswordAuthenticationToken(
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
        if (request.getCookies() == null) return null;
        return Arrays.stream(request.getCookies())
                .filter(c -> accessTokenCookieName.equals(c.getName()))
                .map(Cookie::getValue)
                .findFirst().orElse(null);
    }
}
```

```java
// ✅ CORRECT: Auth controller sets JWT in HTTP-only cookies
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final CookieUtils cookieUtils;

    public AuthController(AuthService authService, CookieUtils cookieUtils) {
        this.authService = authService;
        this.cookieUtils = cookieUtils;
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        AuthTokens tokens = authService.login(request);
        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE,
                        cookieUtils.createAccessTokenCookie(tokens.accessToken()).toString())
                .header(HttpHeaders.SET_COOKIE,
                        cookieUtils.createRefreshTokenCookie(tokens.refreshToken()).toString())
                .body(new AuthResponse(tokens.user()));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(HttpServletRequest request) {
        authService.logout(request);
        return ResponseEntity.noContent()
                .header(HttpHeaders.SET_COOKIE, cookieUtils.deleteAccessTokenCookie().toString())
                .header(HttpHeaders.SET_COOKIE, cookieUtils.deleteRefreshTokenCookie().toString())
                .build();
    }
}
```

```java
// ❌ WRONG: Returning JWT in response body — tokens in localStorage
@PostMapping("/login")
public ResponseEntity<Map<String, String>> login(@RequestBody LoginRequest request) {
    String token = authService.generateToken(request);
    // ❌ Client will store in localStorage — vulnerable to XSS
    return ResponseEntity.ok(Map.of("access_token", token));
}

// ❌ WRONG: Reading JWT from Authorization header
private String extractToken(HttpServletRequest request) {
    String header = request.getHeader("Authorization");  // ❌ Use cookies instead
    if (header != null && header.startsWith("Bearer ")) {
        return header.substring(7);
    }
    return null;
}
```

### Auth in Controllers — CORRECT vs WRONG

```java
// ✅ CORRECT: Controller relies on SecurityFilterChain for auth — no auth annotations needed
@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping("/{userId}")
    // No @PreAuthorize needed — SecurityFilterChain requires authentication for /api/**
    public ResponseEntity<UserResponse> getUser(
            @PathVariable Long userId,
            @AuthenticationPrincipal CustomUserDetails currentUser) {
        return ResponseEntity.ok(userService.getById(userId));
    }
}

// ✅ CORRECT: @PreAuthorize ONLY for granular RBAC permissions (not basic auth)
@RestController
@RequestMapping("/api/admin/users")
public class AdminUserController {

    @DeleteMapping("/{userId}")
    @PreAuthorize("hasPermission('users:delete')")  // ✅ OK — granular RBAC permission
    public ResponseEntity<Void> deleteUser(@PathVariable Long userId) {
        userService.delete(userId);
        return ResponseEntity.noContent().build();
    }
}

// ❌ WRONG: Checking isAuthenticated in controller — SecurityFilterChain already does this
@GetMapping("/{userId}")
@PreAuthorize("isAuthenticated()")  // ❌ REDUNDANT — remove this
public ResponseEntity<UserResponse> getUser(@PathVariable Long userId) { ... }

// ❌ WRONG: Manual auth check in controller method
@GetMapping("/profile")
public ResponseEntity<UserResponse> getProfile(
        @AuthenticationPrincipal CustomUserDetails user) {
    if (user == null) {  // ❌ NEVER check auth in controller — middleware does it
        throw new UnauthorizedException("Not authenticated");
    }
    return ResponseEntity.ok(userService.getProfile(user.getId()));
}
```

---

## 3. Google OAuth2 — Server-Side Authorization Code Grant

```java
// ✅ CORRECT: Server-side OAuth2 callback — issue JWT cookies
@RestController
@RequestMapping("/api/auth")
public class OAuthController {

    private final OAuthService oAuthService;
    private final CookieUtils cookieUtils;

    @Value("${app.frontend-url}")
    private String frontendUrl;

    public OAuthController(OAuthService oAuthService, CookieUtils cookieUtils) {
        this.oAuthService = oAuthService;
        this.cookieUtils = cookieUtils;
    }

    @GetMapping("/google")
    public ResponseEntity<Void> googleLogin() {
        String authorizationUrl = oAuthService.buildGoogleAuthorizationUrl();
        return ResponseEntity.status(HttpStatus.FOUND)
                .header(HttpHeaders.LOCATION, authorizationUrl).build();
    }

    @GetMapping("/google/callback")
    public ResponseEntity<Void> googleCallback(@RequestParam String code) {
        AuthTokens tokens = oAuthService.handleGoogleCallback(code);
        return ResponseEntity.status(HttpStatus.FOUND)
                .header(HttpHeaders.LOCATION, frontendUrl + "/dashboard")
                .header(HttpHeaders.SET_COOKIE,
                        cookieUtils.createAccessTokenCookie(tokens.accessToken()).toString())
                .header(HttpHeaders.SET_COOKIE,
                        cookieUtils.createRefreshTokenCookie(tokens.refreshToken()).toString())
                .build();
    }
}
```

```java
// ✅ CORRECT: OAuth service — exchange code, find-or-create user, issue JWT
@Service
public class OAuthService {

    private final RestClient restClient;
    private final UserRepository userRepository;
    private final JwtProvider jwtProvider;
    private final CustomUserDetailsService userDetailsService;

    @Value("${app.oauth2.google.client-id}")
    private String clientId;

    @Value("${app.oauth2.google.client-secret}")
    private String clientSecret;

    @Value("${app.oauth2.google.redirect-uri}")
    private String redirectUri;

    public OAuthService(RestClient.Builder builder, UserRepository userRepository,
                        JwtProvider jwtProvider, CustomUserDetailsService userDetailsService) {
        this.restClient = builder.build();
        this.userRepository = userRepository;
        this.jwtProvider = jwtProvider;
        this.userDetailsService = userDetailsService;
    }

    public String buildGoogleAuthorizationUrl() {
        return "https://accounts.google.com/o/oauth2/v2/auth?"
                + "client_id=" + clientId
                + "&redirect_uri=" + URLEncoder.encode(redirectUri, StandardCharsets.UTF_8)
                + "&response_type=code&scope=openid%20email%20profile&access_type=offline";
    }

    @Transactional
    public AuthTokens handleGoogleCallback(String code) {
        // Exchange code for tokens
        GoogleTokenResponse tokenResp = restClient.post()
                .uri("https://oauth2.googleapis.com/token")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body("code=" + code + "&client_id=" + clientId
                      + "&client_secret=" + clientSecret
                      + "&redirect_uri=" + redirectUri
                      + "&grant_type=authorization_code")
                .retrieve().body(GoogleTokenResponse.class);

        // Fetch user info
        GoogleUserInfo info = restClient.get()
                .uri("https://www.googleapis.com/oauth2/v3/userinfo")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenResp.accessToken())
                .retrieve().body(GoogleUserInfo.class);

        // Find or create user
        User user = userRepository.findByGoogleSub(info.sub())
                .orElseGet(() -> userRepository.findByEmail(info.email())
                        .map(existing -> {
                            existing.setGoogleSub(info.sub());
                            existing.setAvatarUrl(info.picture());
                            return userRepository.save(existing);
                        })
                        .orElseGet(() -> {
                            User u = new User();
                            u.setEmail(info.email());
                            u.setName(info.name());
                            u.setAvatarUrl(info.picture());
                            u.setGoogleSub(info.sub());
                            u.setEmailVerified(true);
                            u.setAuthProvider(AuthProvider.GOOGLE);
                            return userRepository.save(u);
                        }));

        UserDetails details = userDetailsService.loadUserByUsername(user.getEmail());
        return new AuthTokens(
                jwtProvider.generateAccessToken(details),
                jwtProvider.generateRefreshToken(details),
                UserMapper.toResponse(user));
    }
}

record GoogleTokenResponse(@JsonProperty("access_token") String accessToken,
                            @JsonProperty("id_token") String idToken) {}
record GoogleUserInfo(String sub, String email, String name, String picture) {}
```

```java
// ❌ WRONG: Trusting client-side Google token
@PostMapping("/google")
public ResponseEntity<?> googleLogin(@RequestBody Map<String, String> body) {
    String clientToken = body.get("id_token");  // ❌ Never trust client-sent tokens
    GoogleIdToken.Payload payload = verifyGoogleToken(clientToken);  // ❌ Client could forge
    return ResponseEntity.ok(Map.of("token", generateJwt(payload)));
}
```

---

## 4. Email Sending — spring-boot-starter-mail + @Async + Thymeleaf

```java
// ✅ CORRECT: Async config with dedicated thread pool
@Configuration
@EnableAsync
public class AsyncConfig {

    @Bean("emailTaskExecutor")
    public TaskExecutor emailTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(5);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("email-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return executor;
    }
}
```

```java
// ✅ CORRECT: Email service using Thymeleaf + @Async
@Service
public class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);
    private final JavaMailSender mailSender;
    private final SpringTemplateEngine templateEngine;

    @Value("${app.mail.from}")
    private String fromAddress;

    @Value("${app.mail.from-name}")
    private String fromName;

    public EmailService(JavaMailSender mailSender, SpringTemplateEngine templateEngine) {
        this.mailSender = mailSender;
        this.templateEngine = templateEngine;
    }

    @Async("emailTaskExecutor")
    public void sendWelcomeEmail(String to, String userName) {
        Context ctx = new Context();
        ctx.setVariable("userName", userName);
        ctx.setVariable("loginUrl", "https://app.example.com/login");
        sendHtmlEmail(to, "Welcome to Alpha AI!", "emails/welcome", ctx);
    }

    @Async("emailTaskExecutor")
    public void sendOtpEmail(String to, String otp, int expiryMinutes) {
        Context ctx = new Context();
        ctx.setVariable("otp", otp);
        ctx.setVariable("expiryMinutes", expiryMinutes);
        sendHtmlEmail(to, "Your Verification Code: " + otp, "emails/otp", ctx);
    }

    @Async("emailTaskExecutor")
    public void sendPasswordResetEmail(String to, String resetLink) {
        Context ctx = new Context();
        ctx.setVariable("resetLink", resetLink);
        sendHtmlEmail(to, "Reset Your Password", "emails/password-reset", ctx);
    }

    private void sendHtmlEmail(String to, String subject, String template, Context ctx) {
        try {
            String html = templateEngine.process(template, ctx);
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(new InternetAddress(fromAddress, fromName));
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(html, true);
            mailSender.send(message);
            log.info("Email sent to={} subject={}", to, subject);
        } catch (Exception e) {
            log.error("Failed to send email to={} subject={}", to, subject, e);
        }
    }
}
```

```java
// ❌ WRONG: Blocking email send in API handler
@PostMapping("/register")
public ResponseEntity<UserResponse> register(@Valid @RequestBody RegisterRequest request) {
    User user = authService.register(request);
    // ❌ Synchronous email blocks the API response for 2-5 seconds
    MimeMessage msg = mailSender.createMimeMessage();
    MimeMessageHelper helper = new MimeMessageHelper(msg);
    helper.setTo(user.getEmail());
    helper.setSubject("Welcome!");
    helper.setText("<h1>Welcome</h1>", true);
    mailSender.send(msg);  // ❌ Blocks until SMTP server responds
    return ResponseEntity.ok(UserMapper.toResponse(user));
}
```

---

## 5. RBAC — @PreAuthorize + Custom Security Expressions

```java
// ✅ CORRECT: Granular permission-based RBAC entities
@Entity
@Table(name = "permissions")
public class Permission {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String name;  // e.g. "users:read", "users:delete", "reports:export"

    // getters/setters
}

@Entity
@Table(name = "roles")
public class Role {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String name;  // e.g. "ADMIN", "EDITOR", "VIEWER"

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(name = "role_permissions",
            joinColumns = @JoinColumn(name = "role_id"),
            inverseJoinColumns = @JoinColumn(name = "permission_id"))
    private Set<Permission> permissions = new HashSet<>();

    // getters/setters
}
```

```java
// ✅ CORRECT: Custom security expression for permission checks
public class CustomMethodSecurityExpressionRoot extends SecurityExpressionRoot
        implements MethodSecurityExpressionOperations {

    private Object filterObject;
    private Object returnObject;

    public CustomMethodSecurityExpressionRoot(Authentication authentication) {
        super(authentication);
    }

    public boolean hasPermission(String permission) {
        return getAuthentication().getAuthorities().stream()
                .anyMatch(auth -> auth.getAuthority().equals("PERM_" + permission));
    }

    @Override public void setFilterObject(Object o) { this.filterObject = o; }
    @Override public Object getFilterObject() { return filterObject; }
    @Override public void setReturnObject(Object o) { this.returnObject = o; }
    @Override public Object getReturnObject() { return returnObject; }
    @Override public Object getThis() { return this; }
}
```

```java
// ✅ CORRECT: Controller with granular @PreAuthorize for RBAC permissions
// NOTE: @PreAuthorize("hasPermission(...)") and @PreAuthorize("hasRole(...)") are OK for granular RBAC.
//       @PreAuthorize("isAuthenticated()") is NEVER needed — SecurityFilterChain handles basic auth.
@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    @PreAuthorize("hasPermission('users:read')")  // ✅ OK — granular permission check
    public ResponseEntity<PagedResponse<UserResponse>> listUsers(Pageable pageable) {
        return ResponseEntity.ok(userService.listAll(pageable));
    }

    @DeleteMapping("/{userId}")
    @PreAuthorize("hasPermission('users:delete')")  // ✅ OK — granular permission check
    public ResponseEntity<Void> deleteUser(@PathVariable Long userId) {
        userService.delete(userId);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/{userId}/role")
    @PreAuthorize("hasRole('ADMIN') and hasPermission('users:manage-roles')")  // ✅ OK — role + permission
    public ResponseEntity<UserResponse> assignRole(
            @PathVariable Long userId, @Valid @RequestBody AssignRoleRequest request) {
        return ResponseEntity.ok(userService.assignRole(userId, request));
    }
}
```

```java
// ❌ WRONG: Simple string role check — no granular permissions
@DeleteMapping("/{userId}")
public ResponseEntity<Void> deleteUser(@PathVariable Long userId,
                                        @AuthenticationPrincipal UserDetails user) {
    // ❌ Hardcoded role check — not scalable, not granular
    if (!user.getAuthorities().stream()
            .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"))) {
        throw new AccessDeniedException("Not an admin");
    }
    userService.delete(userId);
    return ResponseEntity.noContent().build();
}
```

---

## 6. File Upload — Presigned URL Pattern with AWS SDK v2

```java
// ✅ CORRECT: Generate presigned URL — client uploads directly to S3
@Service
public class StorageService {

    private final S3Presigner s3Presigner;
    private final S3Client s3Client;

    @Value("${app.aws.s3.bucket}")
    private String bucket;

    public StorageService(S3Presigner s3Presigner, S3Client s3Client) {
        this.s3Presigner = s3Presigner;
        this.s3Client = s3Client;
    }

    public PresignedUrlResponse generateUploadUrl(String userId, String filename,
                                                    String contentType) {
        String fileKey = "uploads/%s/%s/%s".formatted(
                userId, UUID.randomUUID(), sanitizeFilename(filename));

        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(bucket).key(fileKey).contentType(contentType).build();

        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(15))
                .putObjectRequest(putRequest).build();

        PresignedPutObjectRequest presigned = s3Presigner.presignPutObject(presignRequest);
        return new PresignedUrlResponse(presigned.url().toString(), fileKey,
                presigned.expiration());
    }

    public void deleteFile(String fileKey) {
        s3Client.deleteObject(DeleteObjectRequest.builder()
                .bucket(bucket).key(fileKey).build());
    }

    private String sanitizeFilename(String filename) {
        return filename.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}

public record PresignedUrlResponse(String uploadUrl, String fileKey, Instant expiresAt) {}
```

```java
// ✅ CORRECT: Controller returns presigned URL
@RestController
@RequestMapping("/api/upload")
public class UploadController {

    private final StorageService storageService;

    public UploadController(StorageService storageService) {
        this.storageService = storageService;
    }

    @PostMapping("/presigned-url")
    // No @PreAuthorize needed — SecurityFilterChain requires auth for /api/**
    public ResponseEntity<PresignedUrlResponse> getPresignedUrl(
            @Valid @RequestBody UploadRequest request,
            @AuthenticationPrincipal CustomUserDetails user) {
        return ResponseEntity.ok(storageService.generateUploadUrl(
                user.getUserId().toString(), request.filename(), request.contentType()));
    }
}

public record UploadRequest(
        @NotBlank String filename,
        @NotBlank @Pattern(regexp = "^(image|video|application)/.+$") String contentType
) {}
```

```java
// ❌ WRONG: Accepting file upload in API body — blocks server, memory issues
@PostMapping("/upload")
public ResponseEntity<String> upload(@RequestParam("file") MultipartFile file) {
    // ❌ File sits in server memory — OOM risk on large files
    byte[] bytes = file.getBytes();
    s3Client.putObject(PutObjectRequest.builder().bucket(bucket).key(key).build(),
            RequestBody.fromBytes(bytes));  // ❌ Server becomes bottleneck
    return ResponseEntity.ok("Uploaded");
}
```

---

## 7. Point Deduction — Credit Points Billing with JPA + Redis

```java
// ✅ CORRECT: Custom annotation for point-gated endpoints
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RequirePoints {
    int cost();
    String action() default "ai_generation";
}
```

```java
// ✅ CORRECT: AOP aspect to check and deduct points
@Aspect
@Component
public class PointDeductionAspect {

    private final PointService pointService;

    public PointDeductionAspect(PointService pointService) {
        this.pointService = pointService;
    }

    @Around("@annotation(requirePoints)")
    public Object checkAndDeductPoints(ProceedingJoinPoint joinPoint,
                                        RequirePoints requirePoints) throws Throwable {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        CustomUserDetails user = (CustomUserDetails) auth.getPrincipal();
        int cost = requirePoints.cost();

        int balance = pointService.getBalance(user.getUserId());
        if (balance < cost) {
            throw new InsufficientPointsException(cost, balance);
        }
        Object result = joinPoint.proceed();
        pointService.deduct(user.getUserId(), cost, requirePoints.action());
        return result;
    }
}
```

```java
// ✅ CORRECT: Point service with Redis caching
@Service
public class PointService {

    private final PointLedgerRepository ledgerRepository;
    private final RedisTemplate<String, String> redisTemplate;

    public PointService(PointLedgerRepository ledgerRepository,
                        RedisTemplate<String, String> redisTemplate) {
        this.ledgerRepository = ledgerRepository;
        this.redisTemplate = redisTemplate;
    }

    @Transactional(readOnly = true)
    public int getBalance(Long userId) {
        String cached = redisTemplate.opsForValue().get("points:" + userId);
        if (cached != null) return Integer.parseInt(cached);
        int balance = ledgerRepository.sumByUserId(userId);
        redisTemplate.opsForValue().set("points:" + userId,
                String.valueOf(balance), Duration.ofMinutes(5));
        return balance;
    }

    @Transactional
    public void deduct(Long userId, int amount, String action) {
        PointLedger entry = new PointLedger();
        entry.setUserId(userId);
        entry.setAmount(-amount);
        entry.setAction(action);
        entry.setCreatedAt(Instant.now());
        ledgerRepository.save(entry);
        redisTemplate.delete("points:" + userId);
    }

    @Transactional
    public void credit(Long userId, int amount, String reason) {
        PointLedger entry = new PointLedger();
        entry.setUserId(userId);
        entry.setAmount(amount);
        entry.setAction(reason);
        entry.setCreatedAt(Instant.now());
        ledgerRepository.save(entry);
        redisTemplate.delete("points:" + userId);
    }
}
```

```java
// ✅ CORRECT: Usage on controller
@PostMapping("/generate")
@RequirePoints(cost = 10, action = "ai_text_generation")
public ResponseEntity<GenerateResponse> generate(
        @Valid @RequestBody GenerateRequest request,
        @AuthenticationPrincipal CustomUserDetails user) {
    return ResponseEntity.ok(aiService.generate(request, user.getUserId()));
}
```

```java
// ❌ WRONG: No point gate on GenAI endpoint — unlimited usage = cost leak
@PostMapping("/generate")
public ResponseEntity<GenerateResponse> generate(@RequestBody GenerateRequest request) {
    // ❌ No cost control — any user can call unlimited times
    return ResponseEntity.ok(aiService.generate(request));
}
```

---

## 8. Webhook Verification — Razorpay HMAC SHA256

```java
// ✅ CORRECT: Webhook with signature verification + idempotency
@RestController
@RequestMapping("/api/webhooks")
public class WebhookController {

    private final WebhookService webhookService;

    public WebhookController(WebhookService webhookService) {
        this.webhookService = webhookService;
    }

    @PostMapping("/razorpay")
    public ResponseEntity<Map<String, String>> handleRazorpay(
            @RequestBody String rawBody,
            @RequestHeader("X-Razorpay-Signature") String signature) {
        webhookService.processRazorpayWebhook(rawBody, signature);
        return ResponseEntity.ok(Map.of("status", "ok"));
    }
}
```

```java
// ✅ CORRECT: Webhook service with HMAC + Redis deduplication
@Service
public class WebhookService {

    private static final Logger log = LoggerFactory.getLogger(WebhookService.class);

    private final ObjectMapper objectMapper;
    private final RedisTemplate<String, String> redisTemplate;
    private final PointService pointService;
    private final SubscriptionService subscriptionService;

    @Value("${app.razorpay.webhook-secret}")
    private String webhookSecret;

    public WebhookService(ObjectMapper objectMapper,
                          RedisTemplate<String, String> redisTemplate,
                          PointService pointService,
                          SubscriptionService subscriptionService) {
        this.objectMapper = objectMapper;
        this.redisTemplate = redisTemplate;
        this.pointService = pointService;
        this.subscriptionService = subscriptionService;
    }

    public void processRazorpayWebhook(String rawBody, String signature) {
        verifySignature(rawBody, signature);

        JsonNode event;
        try { event = objectMapper.readTree(rawBody); }
        catch (JsonProcessingException e) { throw new BadRequestException("Invalid payload"); }

        String eventId = event.path("event_id").asText();
        String dedupeKey = "rzp_webhook:" + eventId;
        Boolean isNew = redisTemplate.opsForValue()
                .setIfAbsent(dedupeKey, "1", Duration.ofHours(48));
        if (Boolean.FALSE.equals(isNew)) {
            log.info("Duplicate webhook ignored: eventId={}", eventId);
            return;
        }

        String eventType = event.path("event").asText();
        switch (eventType) {
            case "payment.captured" -> handlePaymentCaptured(event);
            case "subscription.activated" -> subscriptionService.activate(
                    event.at("/payload/subscription/entity/id").asText());
            case "subscription.charged" -> subscriptionService.renewPoints(
                    event.at("/payload/subscription/entity/id").asText());
            case "subscription.cancelled" -> subscriptionService.markForDowngrade(
                    event.at("/payload/subscription/entity/id").asText());
            default -> log.warn("Unhandled Razorpay event: {}", eventType);
        }
    }

    private void verifySignature(String rawBody, String signature) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(
                    webhookSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(rawBody.getBytes(StandardCharsets.UTF_8));
            String expected = HexFormat.of().formatHex(hash);
            if (!MessageDigest.isEqual(expected.getBytes(), signature.getBytes())) {
                throw new UnauthorizedException("Invalid Razorpay webhook signature");
            }
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new InternalServerException("Signature verification failed", e);
        }
    }

    private void handlePaymentCaptured(JsonNode event) {
        String orderId = event.at("/payload/payment/entity/order_id").asText();
        int amount = event.at("/payload/payment/entity/amount").asInt();
        log.info("Payment captured: orderId={} amount={}", orderId, amount);
        pointService.creditFromPayment(orderId, amount);
    }
}
```

```java
// ❌ WRONG: No signature verification — anyone can call this endpoint
@PostMapping("/razorpay")
public ResponseEntity<String> webhook(@RequestBody Map<String, Object> payload) {
    // ❌ No signature check — attackers can forge events
    // ❌ No idempotency — duplicates cause double credits
    String event = (String) payload.get("event");
    if ("payment.captured".equals(event)) {
        pointService.credit(userId, amount, "payment");
    }
    return ResponseEntity.ok("ok");
}
```

---

## 9. GenAI Gateway — Spring AI + Model Registry

```java
// ✅ CORRECT: Spring AI gateway with model registry and fallbacks
@Service
public class AiGateway {

    private static final Logger log = LoggerFactory.getLogger(AiGateway.class);

    private final Map<String, ChatModel> modelRegistry;

    private static final Map<String, String> MODEL_TIERS = Map.of(
            "fast", "gpt-4o-mini",
            "smart", "claude-sonnet-4-6",
            "premium", "claude-opus-4-6",
            "gemini", "gemini-2.5-pro"
    );
    private static final List<String> FALLBACK_ORDER = List.of(
            "claude-sonnet-4-6", "gpt-4o", "gemini-2.5-pro");

    public AiGateway(Map<String, ChatModel> modelRegistry) {
        this.modelRegistry = modelRegistry;
    }

    public String generate(String prompt, String tier) {
        String modelName = MODEL_TIERS.getOrDefault(tier, MODEL_TIERS.get("smart"));
        ChatModel model = modelRegistry.get(modelName);
        try {
            ChatResponse response = model.call(new Prompt(prompt));
            return response.getResult().getOutput().getText();
        } catch (Exception e) {
            log.warn("Primary model {} failed, trying fallbacks", modelName, e);
            return tryFallbacks(prompt, modelName);
        }
    }

    public Flux<String> stream(String prompt, String tier) {
        String modelName = MODEL_TIERS.getOrDefault(tier, MODEL_TIERS.get("smart"));
        StreamingChatModel streamModel = (StreamingChatModel) modelRegistry.get(modelName);
        return streamModel.stream(new Prompt(prompt))
                .map(r -> r.getResult().getOutput().getText())
                .filter(Objects::nonNull);
    }

    private String tryFallbacks(String prompt, String failedModel) {
        for (String fallback : FALLBACK_ORDER) {
            if (fallback.equals(failedModel)) continue;
            ChatModel model = modelRegistry.get(fallback);
            if (model == null) continue;
            try {
                ChatResponse response = model.call(new Prompt(prompt));
                log.info("Fallback to {} succeeded", fallback);
                return response.getResult().getOutput().getText();
            } catch (Exception e) {
                log.warn("Fallback {} also failed", fallback, e);
            }
        }
        throw new AiServiceUnavailableException("All AI models are unavailable");
    }
}
```

```java
// ✅ CORRECT: Model registry configuration
@Configuration
public class AiConfig {

    @Bean
    public Map<String, ChatModel> modelRegistry(
            @Value("${spring.ai.openai.api-key}") String openAiKey,
            @Value("${spring.ai.anthropic.api-key}") String anthropicKey) {

        Map<String, ChatModel> registry = new HashMap<>();
        var openAiApi = new OpenAiApi(openAiKey);
        registry.put("gpt-4o-mini", new OpenAiChatModel(openAiApi,
                OpenAiChatOptions.builder().model("gpt-4o-mini").temperature(0.7).build()));
        registry.put("gpt-4o", new OpenAiChatModel(openAiApi,
                OpenAiChatOptions.builder().model("gpt-4o").temperature(0.7).build()));

        var anthropicApi = new AnthropicApi(anthropicKey);
        registry.put("claude-sonnet-4-6", new AnthropicChatModel(anthropicApi,
                AnthropicChatOptions.builder().model("claude-sonnet-4-6").temperature(0.7).build()));
        registry.put("claude-opus-4-6", new AnthropicChatModel(anthropicApi,
                AnthropicChatOptions.builder().model("claude-opus-4-6").temperature(0.7).build()));
        return registry;
    }
}
```

```java
// ❌ WRONG: Direct provider SDK — locked to one LLM vendor
@Service
public class AiService {
    private final OpenAiChatClient openAiClient;  // ❌ Vendor lock-in

    public String generate(String prompt) {
        return openAiClient.call(prompt);  // ❌ No fallback, no registry, no tiers
    }
}
```

---

## 10. RAG Retrieval — Qdrant + Spring AI Embeddings

```java
// ✅ CORRECT: Hybrid retrieval with vector search + chunking
@Service
public class RagRetriever {

    private final VectorStore vectorStore;
    private final EmbeddingModel embeddingModel;

    public RagRetriever(VectorStore vectorStore, EmbeddingModel embeddingModel) {
        this.vectorStore = vectorStore;
        this.embeddingModel = embeddingModel;
    }

    public List<RetrievedDocument> retrieve(String query, int topK) {
        SearchRequest searchRequest = SearchRequest.builder()
                .query(query).topK(topK).similarityThreshold(0.7).build();
        List<Document> results = vectorStore.similaritySearch(searchRequest);
        return results.stream()
                .map(doc -> new RetrievedDocument(doc.getText(), doc.getMetadata(), doc.getScore()))
                .toList();
    }

    public void indexDocument(String documentId, String text, Map<String, Object> metadata) {
        List<String> chunks = chunkText(text, 512, 50);
        List<Document> documents = chunks.stream()
                .map(chunk -> {
                    Map<String, Object> meta = new HashMap<>(metadata);
                    meta.put("documentId", documentId);
                    return new Document(chunk, meta);
                }).toList();
        vectorStore.add(documents);
    }

    private List<String> chunkText(String text, int chunkSize, int overlap) {
        List<String> chunks = new ArrayList<>();
        String[] sentences = text.split("(?<=[.!?])\\s+");
        StringBuilder current = new StringBuilder();
        for (String sentence : sentences) {
            if (current.length() + sentence.length() > chunkSize && !current.isEmpty()) {
                chunks.add(current.toString().trim());
                String tail = current.substring(Math.max(0, current.length() - overlap));
                current = new StringBuilder(tail);
            }
            current.append(sentence).append(" ");
        }
        if (!current.isEmpty()) chunks.add(current.toString().trim());
        return chunks;
    }
}

public record RetrievedDocument(String text, Map<String, Object> metadata, double score) {}
```

```java
// ✅ CORRECT: Qdrant VectorStore configuration
@Configuration
public class VectorStoreConfig {

    @Bean
    public VectorStore vectorStore(EmbeddingModel embeddingModel,
                                    @Value("${app.qdrant.host}") String host,
                                    @Value("${app.qdrant.port}") int port,
                                    @Value("${app.qdrant.collection}") String collection) {
        QdrantClient client = new QdrantClient(
                QdrantGrpcClient.newBuilder(host, port, false).build());
        return new QdrantVectorStore(client, collection, embeddingModel);
    }
}
```

```java
// ❌ WRONG: Stuffing full documents into context
String context = String.join("\n", allDocs);  // ❌ Token waste, context overflow
return aiGateway.generate("Context: " + context + "\nQuestion: " + query, "smart");
```

---

## 11. AI Streaming — SSE via SseEmitter / WebFlux

```java
// ✅ CORRECT: Server-Sent Events streaming for AI chat
@RestController
@RequestMapping("/api/ai")
public class AiChatController {

    private final AiGateway aiGateway;

    public AiChatController(AiGateway aiGateway) {
        this.aiGateway = aiGateway;
    }

    // Option A: SseEmitter (Spring MVC)
    @PostMapping("/chat/stream")
    @RequirePoints(cost = 5, action = "ai_chat")
    public SseEmitter chatStream(@Valid @RequestBody ChatRequest request) {
        SseEmitter emitter = new SseEmitter(120_000L);
        CompletableFuture.runAsync(() -> {
            try {
                aiGateway.stream(request.message(), "smart")
                    .doOnNext(chunk -> {
                        try {
                            emitter.send(SseEmitter.event()
                                    .name("message").data(Map.of("content", chunk)));
                        } catch (IOException e) { emitter.completeWithError(e); }
                    })
                    .doOnComplete(() -> {
                        try {
                            emitter.send(SseEmitter.event().name("done").data("[DONE]"));
                            emitter.complete();
                        } catch (IOException e) { emitter.completeWithError(e); }
                    })
                    .doOnError(emitter::completeWithError)
                    .subscribe();
            } catch (Exception e) { emitter.completeWithError(e); }
        });
        return emitter;
    }

    // Option B: WebFlux Flux<ServerSentEvent>
    @PostMapping(value = "/chat/reactive", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @RequirePoints(cost = 5, action = "ai_chat")
    public Flux<ServerSentEvent<String>> chatReactive(@Valid @RequestBody ChatRequest request) {
        return aiGateway.stream(request.message(), "smart")
                .map(chunk -> ServerSentEvent.<String>builder()
                        .event("message").data(chunk).build())
                .concatWith(Flux.just(ServerSentEvent.<String>builder()
                        .event("done").data("[DONE]").build()));
    }
}

public record ChatRequest(
        @NotBlank String message,
        @Size(max = 50) List<ChatMessage> history
) {}
public record ChatMessage(String role, String content) {}
```

```java
// ❌ WRONG: Blocking — waits for full AI response before returning
@PostMapping("/chat")
public ResponseEntity<Map<String, String>> chat(@RequestBody ChatRequest request) {
    // ❌ Blocks for 5-30 seconds while AI generates full response
    String response = aiGateway.generate(request.message(), "smart");
    return ResponseEntity.ok(Map.of("text", response));
}
```

---

## 12. MCP Prompt Server — Java Implementation

```java
// ✅ CORRECT: MCP server exposing reusable prompts via JSON-RPC 2.0
@Service
public class McpPromptServer {

    private final Map<String, PromptTemplate> promptRegistry = new ConcurrentHashMap<>();

    public McpPromptServer() { registerDefaults(); }

    private void registerDefaults() {
        promptRegistry.put("code_review", new PromptTemplate(
                "code_review", "Review Code",
                "Analyze code quality and suggest improvements",
                List.of(new PromptArgument("code", "Code to review", true),
                        new PromptArgument("language", "Programming language", false)),
                """
                You are a senior code reviewer. Analyze the following ${language} code:
                ```${language}
                ${code}
                ```
                Review for: correctness, performance, security, readability.
                Provide line-by-line feedback with severity (critical/warning/info).
                """
        ));
        promptRegistry.put("summarize_document", new PromptTemplate(
                "summarize_document", "Summarize Document",
                "Generate concise summary of a document",
                List.of(new PromptArgument("content", "Document content", true)),
                """
                Summarize the following document concisely. Include:
                1. Key points (bullet list)
                2. Main conclusions
                3. Action items (if any)

                Document: ${content}
                """
        ));
    }

    public List<McpPromptInfo> listPrompts() {
        return promptRegistry.values().stream()
                .map(pt -> new McpPromptInfo(pt.name(), pt.title(),
                        pt.description(), pt.arguments()))
                .toList();
    }

    public McpPromptMessage getPrompt(String name, Map<String, String> arguments) {
        PromptTemplate template = promptRegistry.get(name);
        if (template == null) throw new NotFoundException("Prompt not found: " + name);
        for (PromptArgument arg : template.arguments()) {
            if (arg.required() && !arguments.containsKey(arg.name()))
                throw new BadRequestException("Missing required argument: " + arg.name());
        }
        String rendered = template.templateText();
        for (var entry : arguments.entrySet())
            rendered = rendered.replace("${" + entry.getKey() + "}", entry.getValue());
        return new McpPromptMessage("user", rendered);
    }
}

record PromptTemplate(String name, String title, String description,
                       List<PromptArgument> arguments, String templateText) {}
record PromptArgument(String name, String description, boolean required) {}
record McpPromptInfo(String name, String title, String description,
                      List<PromptArgument> arguments) {}
record McpPromptMessage(String role, String content) {}
```

```java
// ✅ CORRECT: JSON-RPC 2.0 endpoint for MCP
@RestController
@RequestMapping("/api/mcp")
public class McpController {

    private final McpPromptServer mcpPromptServer;

    public McpController(McpPromptServer mcpPromptServer) {
        this.mcpPromptServer = mcpPromptServer;
    }

    @PostMapping("/jsonrpc")
    public ResponseEntity<JsonRpcResponse> handleRpc(@RequestBody JsonRpcRequest request) {
        return switch (request.method()) {
            case "prompts/list" -> ResponseEntity.ok(
                    JsonRpcResponse.success(request.id(), mcpPromptServer.listPrompts()));
            case "prompts/get" -> {
                @SuppressWarnings("unchecked")
                var params = (Map<String, Object>) request.params();
                @SuppressWarnings("unchecked")
                var args = (Map<String, String>) params.get("arguments");
                yield ResponseEntity.ok(JsonRpcResponse.success(request.id(),
                        mcpPromptServer.getPrompt((String) params.get("name"), args)));
            }
            default -> ResponseEntity.ok(
                    JsonRpcResponse.error(request.id(), -32601, "Method not found"));
        };
    }
}

record JsonRpcRequest(String jsonrpc, String method, Object params, String id) {}
record JsonRpcResponse(String jsonrpc, String id, Object result, JsonRpcError error) {
    static JsonRpcResponse success(String id, Object result) {
        return new JsonRpcResponse("2.0", id, result, null);
    }
    static JsonRpcResponse error(String id, int code, String message) {
        return new JsonRpcResponse("2.0", id, null, new JsonRpcError(code, message));
    }
}
record JsonRpcError(int code, String message) {}
```

---

## 13. A2A Agent Card — /.well-known/agent.json

```java
// ✅ CORRECT: A2A Agent Card discovery endpoint
@RestController
public class AgentCardController {

    @Value("${app.base-url}")
    private String baseUrl;

    @GetMapping(value = "/.well-known/agent.json",
                produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> getAgentCard() {
        return ResponseEntity.ok(Map.of(
                "name", "alpha-ai-assistant",
                "description", "Alpha AI intelligent assistant with RAG and code generation",
                "url", baseUrl + "/a2a",
                "version", "1.0.0",
                "capabilities", Map.of("streaming", true, "pushNotifications", false),
                "skills", List.of(
                        Map.of("id", "document-analysis",
                               "name", "Document Analysis",
                               "description", "Analyze documents using RAG",
                               "tags", List.of("rag", "analysis")),
                        Map.of("id", "code-generation",
                               "name", "Code Generation",
                               "description", "Generate code from natural language",
                               "tags", List.of("code", "generation"))),
                "authentication", Map.of("schemes", List.of("bearer"))
        ));
    }
}
```

```java
// ❌ WRONG: No agent card endpoint — invisible to A2A ecosystem
// Missing /.well-known/agent.json means other agents cannot discover this service
```

---

## 14. Structured Output — Spring AI with Java Records

```java
// ✅ CORRECT: Spring AI structured output with BeanOutputConverter
@Service
public class StructuredExtractor {

    private final ChatModel chatModel;

    public StructuredExtractor(ChatModel chatModel) {
        this.chatModel = chatModel;
    }

    public <T> T extract(String input, Class<T> responseType, String instruction) {
        BeanOutputConverter<T> converter = new BeanOutputConverter<>(responseType);
        String format = converter.getFormat();
        Prompt prompt = new Prompt(List.of(
                new SystemMessage(instruction + "\n\nRespond in JSON:\n" + format),
                new UserMessage(input)));
        ChatResponse response = chatModel.call(prompt);
        return converter.convert(response.getResult().getOutput().getText());
    }

    public ProductReview extractReview(String reviewText) {
        return extract(reviewText, ProductReview.class,
                "Analyze this product review and extract structured data.");
    }

    public ResumeData extractResume(String resumeText) {
        return extract(resumeText, ResumeData.class,
                "Extract structured information from this resume.");
    }
}

public record ProductReview(String sentiment, double score, List<String> keyPoints,
                             String summary, List<String> pros, List<String> cons) {}
public record ResumeData(String name, String email, String phone,
                          List<WorkExperience> experience, List<String> skills) {}
public record WorkExperience(String company, String title, String startDate,
                              String endDate) {}
```

```java
// ❌ WRONG: Parsing raw AI text with regex
public String extractSentiment(String reviewText) {
    String response = chatModel.call("What is the sentiment? " + reviewText);
    // ❌ Fragile regex — breaks when AI response format changes
    Pattern p = Pattern.compile("sentiment:\\s*(\\w+)");
    Matcher m = p.matcher(response);
    return m.find() ? m.group(1) : "unknown";
}
```

---

## 15. Semantic Caching — Redis + Embedding Cosine Similarity

```java
// ✅ CORRECT: Semantic cache with embedding similarity
@Service
public class SemanticCache {

    private static final Logger log = LoggerFactory.getLogger(SemanticCache.class);
    private static final double CACHE_THRESHOLD = 0.95;
    private static final Duration CACHE_TTL = Duration.ofHours(24);

    private final RedisTemplate<String, String> redisTemplate;
    private final EmbeddingModel embeddingModel;
    private final ObjectMapper objectMapper;

    public SemanticCache(RedisTemplate<String, String> redisTemplate,
                         EmbeddingModel embeddingModel,
                         ObjectMapper objectMapper) {
        this.redisTemplate = redisTemplate;
        this.embeddingModel = embeddingModel;
        this.objectMapper = objectMapper;
    }

    public Optional<String> getCachedResponse(String query) {
        float[] queryEmbed = embed(query);
        Set<String> keys = redisTemplate.keys("ai:cache:*");
        if (keys == null || keys.isEmpty()) return Optional.empty();

        for (String key : keys) {
            String cached = redisTemplate.opsForValue().get(key);
            if (cached == null) continue;
            try {
                CacheEntry entry = objectMapper.readValue(cached, CacheEntry.class);
                double sim = cosineSimilarity(queryEmbed, entry.embedding());
                if (sim >= CACHE_THRESHOLD) {
                    log.debug("Semantic cache HIT: similarity={}", sim);
                    return Optional.of(entry.response());
                }
            } catch (JsonProcessingException e) {
                log.warn("Failed to parse cache entry: key={}", key);
            }
        }
        return Optional.empty();
    }

    public void cacheResponse(String query, String response) {
        float[] embedding = embed(query);
        String key = "ai:cache:" + hashQuery(query);
        try {
            redisTemplate.opsForValue().set(key,
                    objectMapper.writeValueAsString(
                            new CacheEntry(query, response, embedding)),
                    CACHE_TTL);
        } catch (JsonProcessingException e) {
            log.warn("Failed to cache response", e);
        }
    }

    private float[] embed(String text) {
        return embeddingModel.call(new EmbeddingRequest(
                List.of(text), EmbeddingOptions.EMPTY))
                .getResult().getOutput();
    }

    private double cosineSimilarity(float[] a, float[] b) {
        double dot = 0, normA = 0, normB = 0;
        for (int i = 0; i < a.length; i++) {
            dot += a[i] * b[i]; normA += a[i] * a[i]; normB += b[i] * b[i];
        }
        return dot / (Math.sqrt(normA) * Math.sqrt(normB));
    }

    private String hashQuery(String query) {
        try {
            byte[] digest = MessageDigest.getInstance("MD5")
                    .digest(query.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) { throw new RuntimeException(e); }
    }

    record CacheEntry(String query, String response, float[] embedding) {}
}
```

```java
// ❌ WRONG: Exact-match caching only
@Cacheable(value = "ai", key = "#query")
public String generate(String query) {
    // ❌ "What is AI?" and "Explain artificial intelligence" are separate misses
    return aiGateway.generate(query, "smart");
}
```

---

## 16. Agentic RAG — Dynamic Retrieval with Query Decomposition

```java
// ✅ CORRECT: Agent dynamically decides retrieval strategy
@Service
public class AgenticRetriever {

    private final RagRetriever ragRetriever;
    private final ChatModel chatModel;
    private final WebSearchService webSearchService;
    private final ReRanker reRanker;

    public AgenticRetriever(RagRetriever ragRetriever, ChatModel chatModel,
                            WebSearchService webSearchService, ReRanker reRanker) {
        this.ragRetriever = ragRetriever;
        this.chatModel = chatModel;
        this.webSearchService = webSearchService;
        this.reRanker = reRanker;
    }

    public AgenticRagResult retrieve(String query) {
        QueryAnalysis analysis = analyzeQuery(query);
        List<RetrievedDocument> allResults = new ArrayList<>();

        if (analysis.isComplex()) {
            for (String subQuery : decomposeQuery(query))
                allResults.addAll(ragRetriever.retrieve(subQuery, 10));
        } else {
            allResults.addAll(ragRetriever.retrieve(query, 20));
        }

        if (allResults.isEmpty() || allResults.stream().allMatch(r -> r.score() < 0.5)) {
            allResults.addAll(webSearchService.search(query, 10));
        }

        List<RetrievedDocument> reranked = reRanker.rerank(query, allResults, 5);
        return new AgenticRagResult(reranked, analysis,
                reranked.stream().mapToDouble(RetrievedDocument::score).average().orElse(0.0));
    }

    private QueryAnalysis analyzeQuery(String query) {
        BeanOutputConverter<QueryAnalysis> conv = new BeanOutputConverter<>(QueryAnalysis.class);
        String prompt = """
                Analyze this query and respond with JSON:
                {"isComplex": true/false, "requiresWebSearch": true/false, "topics": ["topic1"]}
                Query: %s
                %s""".formatted(query, conv.getFormat());
        ChatResponse resp = chatModel.call(new Prompt(prompt));
        return conv.convert(resp.getResult().getOutput().getText());
    }

    private List<String> decomposeQuery(String query) {
        ChatResponse resp = chatModel.call(new Prompt(
                "Break this query into 2-4 simpler sub-queries. Return JSON array.\nQuery: " + query));
        try {
            return new ObjectMapper().readValue(
                    resp.getResult().getOutput().getText(), new TypeReference<>() {});
        } catch (JsonProcessingException e) { return List.of(query); }
    }
}

record QueryAnalysis(boolean isComplex, boolean requiresWebSearch, List<String> topics) {}
record AgenticRagResult(List<RetrievedDocument> documents, QueryAnalysis analysis,
                         double avgScore) {}
```

```java
// ❌ WRONG: Single-shot naive retrieval
List<Document> docs = vectorStore.similaritySearch(query);  // ❌ No decomposition, no fallback
```

---

## 17. Re-ranking — Post-Retrieval Re-ranking

```java
// ✅ CORRECT: Re-rank after vector retrieval for better precision
@Service
public class ReRanker {

    private static final Logger log = LoggerFactory.getLogger(ReRanker.class);
    private final RestClient restClient;

    @Value("${app.cohere.api-key}")
    private String cohereApiKey;

    public ReRanker(RestClient.Builder builder) {
        this.restClient = builder.baseUrl("https://api.cohere.ai/v1").build();
    }

    public List<RetrievedDocument> rerank(String query,
                                           List<RetrievedDocument> documents, int topN) {
        if (documents.isEmpty()) return List.of();
        List<String> texts = documents.stream().map(RetrievedDocument::text).toList();

        CohereRerankResponse response = restClient.post()
                .uri("/rerank")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + cohereApiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .body(new CohereRerankRequest("rerank-v3.5", query, texts, topN))
                .retrieve().body(CohereRerankResponse.class);

        if (response == null || response.results() == null) {
            log.warn("Re-ranking failed, returning original order");
            return documents.subList(0, Math.min(topN, documents.size()));
        }
        return response.results().stream()
                .map(r -> new RetrievedDocument(documents.get(r.index()).text(),
                        documents.get(r.index()).metadata(), r.relevanceScore()))
                .toList();
    }
}

// Pipeline: retrieve(20) -> rerank(5) -> generate
// List<RetrievedDocument> raw = ragRetriever.retrieve(query, 20);
// List<RetrievedDocument> reranked = reRanker.rerank(query, raw, 5);
// String context = reranked.stream().map(RetrievedDocument::text).collect(joining("\n"));
// String answer = aiGateway.generate("Context:\n" + context + "\nQuestion: " + query, "smart");

record CohereRerankRequest(String model, String query, List<String> documents, int topN) {}
record CohereRerankResponse(List<CohereRerankResult> results) {}
record CohereRerankResult(int index, double relevanceScore) {}
```

```java
// ❌ WRONG: No re-ranking — raw vector scores only
List<Document> docs = vectorStore.similaritySearch(query);
// ❌ First result by vector distance may not be most relevant
return aiGateway.generate("Context: " + docs.get(0).getText() + "\n" + query, "smart");
```

---

## 18. AI Evaluation — JUnit 5 Based LLM Testing

```java
// ✅ CORRECT: LLM quality tests with JUnit 5
@SpringBootTest
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class AiQualityTest {

    @Autowired private AiGateway aiGateway;
    @Autowired private RagRetriever ragRetriever;
    @Autowired private ChatModel evaluatorModel;

    @Test
    @DisplayName("AI response should be relevant to the query")
    void testResponseRelevancy() {
        String query = "What is our refund policy?";
        String response = aiGateway.generate(query, "smart");
        double score = evaluateWithLlm(
                "Rate relevancy of this response to the query (0.0-1.0). Respond ONLY a number.\n"
                + "Query: %s\nResponse: %s".formatted(query, response));
        assertThat(score).as("Response relevancy").isGreaterThanOrEqualTo(0.7);
    }

    @Test
    @DisplayName("AI response should be faithful to context")
    void testFaithfulness() {
        String query = "What is our refund policy?";
        List<RetrievedDocument> ctx = ragRetriever.retrieve(query, 5);
        String contextText = ctx.stream().map(RetrievedDocument::text)
                .collect(Collectors.joining("\n"));
        String response = aiGateway.generate(
                "Based on this context:\n" + contextText + "\nQuestion: " + query, "smart");
        double score = evaluateWithLlm(
                "Rate faithfulness of response to context (0.0-1.0). ONLY a number.\n"
                + "Context: %s\nResponse: %s".formatted(contextText, response));
        assertThat(score).as("Faithfulness").isGreaterThanOrEqualTo(0.8);
    }

    @Test
    @DisplayName("AI should not hallucinate facts")
    void testNoHallucination() {
        String context = "Our company was founded in 2020. We have 50 employees.";
        String response = aiGateway.generate(
                "Context: " + context + "\nWhat year was the company founded?", "smart");
        double score = evaluateWithLlm(
                "Rate hallucination level (0.0=none, 1.0=fully hallucinated). ONLY a number.\n"
                + "Context: %s\nResponse: %s".formatted(context, response));
        assertThat(score).as("Hallucination (lower=better)").isLessThanOrEqualTo(0.3);
    }

    private double evaluateWithLlm(String prompt) {
        String result = evaluatorModel.call(new Prompt(prompt))
                .getResult().getOutput().getText().trim();
        return Double.parseDouble(result);
    }
}
```

```java
// ❌ WRONG: No AI quality tests at all
// "It works on my prompt" is not a test strategy
```

---

## 19. Context Window Management — Token Counting + Auto-Summarization

```java
// ✅ CORRECT: Auto-summarize when conversation exceeds threshold
@Service
public class ContextManager {

    private static final int SUMMARY_THRESHOLD = 6000;
    private static final int KEEP_RECENT = 4;

    private final ChatModel chatModel;
    private final TokenCountEstimator tokenEstimator;

    public ContextManager(ChatModel chatModel, TokenCountEstimator tokenEstimator) {
        this.chatModel = chatModel;
        this.tokenEstimator = tokenEstimator;
    }

    public List<Message> manageContext(List<Message> messages) {
        int tokens = messages.stream()
                .mapToInt(m -> tokenEstimator.estimate(m.getText())).sum();
        if (tokens <= SUMMARY_THRESHOLD) return messages;

        Message systemPrompt = messages.getFirst();
        int splitIdx = Math.max(1, messages.size() - KEEP_RECENT);
        List<Message> old = messages.subList(1, splitIdx);
        List<Message> recent = messages.subList(splitIdx, messages.size());

        StringBuilder convo = new StringBuilder();
        for (Message m : old)
            convo.append(m.getMessageType()).append(": ").append(m.getText()).append("\n");

        String summary = chatModel.call(new Prompt(List.of(
                new SystemMessage("Summarize this conversation concisely."),
                new UserMessage(convo.toString()))))
                .getResult().getOutput().getText();

        List<Message> result = new ArrayList<>();
        result.add(systemPrompt);
        result.add(new SystemMessage("Previous conversation summary: " + summary));
        result.addAll(recent);
        return result;
    }
}

@Component
public class TokenCountEstimator {
    private static final double CHARS_PER_TOKEN = 4.0;
    public int estimate(String text) {
        if (text == null || text.isEmpty()) return 0;
        return (int) Math.ceil(text.length() / CHARS_PER_TOKEN);
    }
}
```

```java
// ❌ WRONG: No context management — sending entire history
public String chat(List<Message> fullHistory, String newMessage) {
    fullHistory.add(new UserMessage(newMessage));
    // ❌ Eventually exceeds context window — API error or truncation
    return chatModel.call(new Prompt(fullHistory)).getResult().getOutput().getText();
}
```

---

## 20. HITL — Human-in-the-Loop Review Queue

```java
// ✅ CORRECT: Review queue for AI-generated content
@Service
public class HitlReviewService {

    private final ReviewQueueRepository reviewQueueRepository;
    private final AiGateway aiGateway;

    @Value("${app.ai.auto-publish-threshold:0.85}")
    private double autoPublishThreshold;

    public HitlReviewService(ReviewQueueRepository reviewQueueRepository,
                              AiGateway aiGateway) {
        this.reviewQueueRepository = reviewQueueRepository;
        this.aiGateway = aiGateway;
    }

    @Transactional
    public HitlResult generateWithReview(String prompt, Long userId, String contentType) {
        String content = aiGateway.generate(prompt, "smart");
        double confidence = estimateConfidence(prompt, content);

        if (confidence >= autoPublishThreshold) {
            return new HitlResult(content, "auto_approved", null, confidence);
        }

        ReviewQueueItem item = new ReviewQueueItem();
        item.setContent(content);
        item.setPrompt(prompt);
        item.setUserId(userId);
        item.setContentType(contentType);
        item.setConfidence(confidence);
        item.setStatus(ReviewStatus.PENDING);
        item.setCreatedAt(Instant.now());
        ReviewQueueItem saved = reviewQueueRepository.save(item);
        return new HitlResult(content, "pending_review", saved.getId(), confidence);
    }

    @Transactional
    public ReviewQueueItem approve(Long reviewId, Long reviewerId, String editedContent) {
        ReviewQueueItem item = reviewQueueRepository.findById(reviewId)
                .orElseThrow(() -> new NotFoundException("Review item not found"));
        item.setStatus(ReviewStatus.APPROVED);
        item.setReviewerId(reviewerId);
        item.setReviewedAt(Instant.now());
        if (editedContent != null) item.setContent(editedContent);
        return reviewQueueRepository.save(item);
    }

    @Transactional
    public ReviewQueueItem reject(Long reviewId, Long reviewerId, String reason) {
        ReviewQueueItem item = reviewQueueRepository.findById(reviewId)
                .orElseThrow(() -> new NotFoundException("Review item not found"));
        item.setStatus(ReviewStatus.REJECTED);
        item.setReviewerId(reviewerId);
        item.setRejectionReason(reason);
        item.setReviewedAt(Instant.now());
        return reviewQueueRepository.save(item);
    }

    private double estimateConfidence(String prompt, String content) {
        try {
            return Double.parseDouble(aiGateway.generate(
                    "Rate confidence in this content (0.0-1.0). ONLY a number.\n"
                    + "Prompt: %s\nContent: %s".formatted(prompt, content), "fast").trim());
        } catch (Exception e) { return 0.5; }
    }
}

record HitlResult(String content, String status, Long reviewId, double confidence) {}
enum ReviewStatus { PENDING, APPROVED, REJECTED }
```

```java
// ✅ CORRECT: HITL controller
@RestController
@RequestMapping("/api/ai/review")
public class HitlController {

    private final HitlReviewService reviewService;

    public HitlController(HitlReviewService reviewService) {
        this.reviewService = reviewService;
    }

    @PostMapping("/generate")
    @RequirePoints(cost = 10, action = "ai_generate_with_review")
    public ResponseEntity<HitlResult> generateWithReview(
            @Valid @RequestBody GenerateRequest request,
            @AuthenticationPrincipal CustomUserDetails user) {
        return ResponseEntity.ok(reviewService.generateWithReview(
                request.prompt(), user.getUserId(), request.contentType()));
    }

    @PostMapping("/{reviewId}/approve")
    @PreAuthorize("hasPermission('ai:review')")
    public ResponseEntity<ReviewQueueItem> approve(
            @PathVariable Long reviewId,
            @RequestBody(required = false) EditContentRequest editReq,
            @AuthenticationPrincipal CustomUserDetails reviewer) {
        return ResponseEntity.ok(reviewService.approve(
                reviewId, reviewer.getUserId(),
                editReq != null ? editReq.content() : null));
    }

    @PostMapping("/{reviewId}/reject")
    @PreAuthorize("hasPermission('ai:review')")
    public ResponseEntity<ReviewQueueItem> reject(
            @PathVariable Long reviewId,
            @Valid @RequestBody RejectRequest request,
            @AuthenticationPrincipal CustomUserDetails reviewer) {
        return ResponseEntity.ok(reviewService.reject(
                reviewId, reviewer.getUserId(), request.reason()));
    }
}
```

```java
// ❌ WRONG: Auto-publishing all AI content without review
@PostMapping("/generate")
public ResponseEntity<String> generate(@RequestBody GenerateRequest request) {
    String content = aiGateway.generate(request.prompt(), "smart");
    contentService.publish(content);  // ❌ No quality gate, no human oversight
    return ResponseEntity.ok(content);
}
```

---

## 21. Voice AI — Whisper STT + TTS Streaming

```java
// ✅ CORRECT: Speech-to-text with Whisper
@Service
public class SpeechToTextService {

    private final RestClient restClient;

    @Value("${spring.ai.openai.api-key}")
    private String openAiApiKey;

    public SpeechToTextService(RestClient.Builder builder) {
        this.restClient = builder.baseUrl("https://api.openai.com/v1").build();
    }

    public TranscriptionResult transcribe(byte[] audioData, String filename, String language) {
        MultipartBodyBuilder builder = new MultipartBodyBuilder();
        builder.part("file", new ByteArrayResource(audioData) {
            @Override public String getFilename() { return filename; }
        }).contentType(MediaType.APPLICATION_OCTET_STREAM);
        builder.part("model", "whisper-1");
        if (language != null) builder.part("language", language);
        builder.part("response_format", "verbose_json");

        WhisperResponse resp = restClient.post()
                .uri("/audio/transcriptions")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + openAiApiKey)
                .contentType(MediaType.MULTIPART_FORM_DATA)
                .body(builder.build())
                .retrieve().body(WhisperResponse.class);
        return new TranscriptionResult(resp.text(), resp.language(), resp.duration());
    }
}

record TranscriptionResult(String text, String language, double durationSeconds) {}
record WhisperResponse(String text, String language, double duration) {}
```

```java
// ✅ CORRECT: Text-to-speech with streaming
@Service
public class TextToSpeechService {

    private final WebClient webClient;

    @Value("${spring.ai.openai.api-key}")
    private String openAiApiKey;

    public TextToSpeechService(WebClient.Builder builder) {
        this.webClient = builder.baseUrl("https://api.openai.com/v1").build();
    }

    public Flux<DataBuffer> synthesize(String text, String voice, String model) {
        return webClient.post()
                .uri("/audio/speech")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + openAiApiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(Map.of(
                        "model", model != null ? model : "tts-1",
                        "input", text,
                        "voice", voice != null ? voice : "alloy",
                        "response_format", "mp3"))
                .retrieve().bodyToFlux(DataBuffer.class);
    }
}
```

```java
// ✅ CORRECT: Voice controller
@RestController
@RequestMapping("/api/ai/voice")
public class VoiceController {

    private final SpeechToTextService sttService;
    private final TextToSpeechService ttsService;

    public VoiceController(SpeechToTextService sttService, TextToSpeechService ttsService) {
        this.sttService = sttService;
        this.ttsService = ttsService;
    }

    @PostMapping("/transcribe")
    @RequirePoints(cost = 5, action = "voice_transcription")
    public ResponseEntity<TranscriptionResult> transcribe(
            @RequestParam("audio") MultipartFile audioFile) throws IOException {
        return ResponseEntity.ok(sttService.transcribe(
                audioFile.getBytes(), audioFile.getOriginalFilename(), null));
    }

    @PostMapping(value = "/synthesize", produces = "audio/mpeg")
    @RequirePoints(cost = 5, action = "voice_synthesis")
    public Flux<DataBuffer> synthesize(@Valid @RequestBody TtsRequest request) {
        return ttsService.synthesize(request.text(), request.voice(), request.model());
    }
}

record TtsRequest(@NotBlank @Size(max = 4096) String text, String voice, String model) {}
```

```java
// ❌ WRONG: Synchronous file download for TTS — blocks server
@PostMapping("/tts")
public ResponseEntity<byte[]> tts(@RequestBody TtsRequest request) {
    // ❌ Downloads entire audio into memory before responding
    byte[] audio = restTemplate.postForObject(url, body, byte[].class);
    return ResponseEntity.ok().contentType(MediaType.valueOf("audio/mpeg")).body(audio);
}
```

---

## 22. Batch AI Processing — @Async + @Scheduled + Progress Tracking

```java
// ✅ CORRECT: Async config for batch processing
@Configuration
public class BatchAsyncConfig {

    @Bean("batchTaskExecutor")
    public TaskExecutor batchTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(3);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(50);
        executor.setThreadNamePrefix("batch-ai-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(60);
        executor.initialize();
        return executor;
    }
}
```

```java
// ✅ CORRECT: Background batch with Redis progress tracking
@Service
public class BatchProcessor {

    private static final Logger log = LoggerFactory.getLogger(BatchProcessor.class);
    private final RagRetriever ragRetriever;
    private final RedisTemplate<String, String> redisTemplate;
    private final ObjectMapper objectMapper;

    public BatchProcessor(RagRetriever ragRetriever,
                          RedisTemplate<String, String> redisTemplate,
                          ObjectMapper objectMapper) {
        this.ragRetriever = ragRetriever;
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
    }

    @Async("batchTaskExecutor")
    public CompletableFuture<BatchResult> batchEmbedDocuments(
            String batchId, List<DocumentInput> documents) {
        int total = documents.size(), completed = 0, failed = 0;
        for (DocumentInput doc : documents) {
            try {
                ragRetriever.indexDocument(doc.id(), doc.text(), doc.metadata());
                completed++;
            } catch (Exception e) {
                log.error("Failed to embed doc: id={}", doc.id(), e);
                failed++;
            }
            updateProgress(batchId, completed, failed, total);
        }
        BatchResult result = new BatchResult(batchId, "completed", completed, failed, total);
        redisTemplate.opsForValue().set("batch:" + batchId + ":result",
                toJson(result), Duration.ofHours(24));
        return CompletableFuture.completedFuture(result);
    }

    private void updateProgress(String batchId, int completed, int failed, int total) {
        redisTemplate.opsForValue().set("batch:" + batchId + ":progress",
                toJson(new BatchProgress(completed, failed, total,
                        Math.round((float) (completed + failed) / total * 100))),
                Duration.ofHours(1));
    }

    private String toJson(Object obj) {
        try { return objectMapper.writeValueAsString(obj); }
        catch (JsonProcessingException e) { throw new RuntimeException(e); }
    }
}

record DocumentInput(String id, String text, Map<String, Object> metadata) {}
record BatchResult(String batchId, String status, int completed, int failed, int total) {}
record BatchProgress(int completed, int failed, int total, int percentComplete) {}
```

```java
// ✅ CORRECT: Batch controller with progress polling
@RestController
@RequestMapping("/api/ai/batch")
public class BatchController {

    private final BatchProcessor batchProcessor;
    private final RedisTemplate<String, String> redisTemplate;
    private final ObjectMapper objectMapper;

    public BatchController(BatchProcessor batchProcessor,
                           RedisTemplate<String, String> redisTemplate,
                           ObjectMapper objectMapper) {
        this.batchProcessor = batchProcessor;
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
    }

    @PostMapping("/embed")
    @PreAuthorize("hasPermission('ai:batch')")
    public ResponseEntity<Map<String, String>> startBatch(
            @Valid @RequestBody BatchEmbedRequest request) {
        String batchId = UUID.randomUUID().toString();
        batchProcessor.batchEmbedDocuments(batchId, request.documents());
        return ResponseEntity.accepted().body(Map.of("batchId", batchId, "status", "started"));
    }

    @GetMapping("/{batchId}/progress")
    public ResponseEntity<BatchProgress> getProgress(@PathVariable String batchId)
            throws JsonProcessingException {
        String json = redisTemplate.opsForValue().get("batch:" + batchId + ":progress");
        if (json == null) throw new NotFoundException("Batch not found: " + batchId);
        return ResponseEntity.ok(objectMapper.readValue(json, BatchProgress.class));
    }
}

record BatchEmbedRequest(@NotEmpty List<DocumentInput> documents) {}
```

```java
// ✅ CORRECT: Scheduled batch cleanup
@Component
public class BatchCleanupScheduler {

    private static final Logger log = LoggerFactory.getLogger(BatchCleanupScheduler.class);
    private final RedisTemplate<String, String> redisTemplate;

    public BatchCleanupScheduler(RedisTemplate<String, String> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Scheduled(cron = "0 0 3 * * *")  // Daily at 3 AM
    public void cleanupExpiredBatches() {
        Set<String> keys = redisTemplate.keys("batch:*:result");
        if (keys != null) log.info("Batch cleanup: checking {} entries", keys.size());
    }
}
```

```java
// ❌ WRONG: Processing batch synchronously in request thread
@PostMapping("/embed-all")
public ResponseEntity<String> embedAll(@RequestBody List<DocumentInput> docs) {
    for (DocumentInput doc : docs)
        ragRetriever.indexDocument(doc.id(), doc.text(), doc.metadata());
    // ❌ Blocks HTTP for potentially hours, no progress tracking, will timeout
    return ResponseEntity.ok("Done");
}
```

---

## 23. Error Handling — @ControllerAdvice + Custom Exceptions

```java
// ✅ CORRECT: Custom exception hierarchy
public class AppException extends RuntimeException {
    private final HttpStatus status;
    private final String errorCode;
    public AppException(String message, HttpStatus status, String errorCode) {
        super(message); this.status = status; this.errorCode = errorCode;
    }
    public HttpStatus getStatus() { return status; }
    public String getErrorCode() { return errorCode; }
}

public class NotFoundException extends AppException {
    public NotFoundException(String msg) { super(msg, HttpStatus.NOT_FOUND, "NOT_FOUND"); }
}
public class BadRequestException extends AppException {
    public BadRequestException(String msg) { super(msg, HttpStatus.BAD_REQUEST, "BAD_REQUEST"); }
}
public class ConflictException extends AppException {
    public ConflictException(String msg) { super(msg, HttpStatus.CONFLICT, "CONFLICT"); }
}
public class UnauthorizedException extends AppException {
    public UnauthorizedException(String msg) { super(msg, HttpStatus.UNAUTHORIZED, "UNAUTHORIZED"); }
}
public class ForbiddenException extends AppException {
    public ForbiddenException(String msg) { super(msg, HttpStatus.FORBIDDEN, "FORBIDDEN"); }
}
public class InsufficientPointsException extends AppException {
    private final int required;
    private final int balance;
    public InsufficientPointsException(int required, int balance) {
        super("Insufficient points: required=%d, balance=%d".formatted(required, balance),
                HttpStatus.PAYMENT_REQUIRED, "INSUFFICIENT_POINTS");
        this.required = required; this.balance = balance;
    }
    public int getRequired() { return required; }
    public int getBalance() { return balance; }
}
public class AiServiceUnavailableException extends AppException {
    public AiServiceUnavailableException(String msg) {
        super(msg, HttpStatus.SERVICE_UNAVAILABLE, "AI_SERVICE_UNAVAILABLE");
    }
}
public class InternalServerException extends AppException {
    public InternalServerException(String msg, Throwable cause) {
        super(msg, HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL_ERROR"); initCause(cause);
    }
}
```

```java
// ✅ CORRECT: Global exception handler with @RestControllerAdvice
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(AppException.class)
    public ResponseEntity<ErrorResponse> handleApp(AppException ex, HttpServletRequest req) {
        log.warn("AppException: status={} code={} msg={} path={}",
                ex.getStatus().value(), ex.getErrorCode(), ex.getMessage(), req.getRequestURI());
        return ResponseEntity.status(ex.getStatus()).body(new ErrorResponse(
                Instant.now(), ex.getStatus().value(), ex.getErrorCode(),
                ex.getMessage(), req.getRequestURI()));
    }

    @ExceptionHandler(InsufficientPointsException.class)
    public ResponseEntity<Map<String, Object>> handleInsufficientPoints(
            InsufficientPointsException ex, HttpServletRequest req) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("timestamp", Instant.now());
        body.put("status", 402);
        body.put("error", "INSUFFICIENT_POINTS");
        body.put("message", ex.getMessage());
        body.put("required", ex.getRequired());
        body.put("balance", ex.getBalance());
        body.put("path", req.getRequestURI());
        return ResponseEntity.status(HttpStatus.PAYMENT_REQUIRED).body(body);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(
            MethodArgumentNotValidException ex, HttpServletRequest req) {
        String msg = ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> fe.getField() + ": " + fe.getDefaultMessage())
                .collect(Collectors.joining(", "));
        return ResponseEntity.unprocessableEntity().body(new ErrorResponse(
                Instant.now(), 422, "VALIDATION_ERROR", msg, req.getRequestURI()));
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDenied(
            AccessDeniedException ex, HttpServletRequest req) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(new ErrorResponse(
                Instant.now(), 403, "FORBIDDEN", "Access denied", req.getRequestURI()));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ErrorResponse> handleConstraint(
            ConstraintViolationException ex, HttpServletRequest req) {
        String msg = ex.getConstraintViolations().stream()
                .map(cv -> cv.getPropertyPath() + ": " + cv.getMessage())
                .collect(Collectors.joining(", "));
        return ResponseEntity.badRequest().body(new ErrorResponse(
                Instant.now(), 400, "CONSTRAINT_VIOLATION", msg, req.getRequestURI()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleUnexpected(
            Exception ex, HttpServletRequest req) {
        log.error("Unexpected error at path={}", req.getRequestURI(), ex);
        return ResponseEntity.internalServerError().body(new ErrorResponse(
                Instant.now(), 500, "INTERNAL_ERROR",
                "An unexpected error occurred", req.getRequestURI()));
    }
}

public record ErrorResponse(Instant timestamp, int status, String error,
                              String message, String path) {}
```

```java
// ❌ WRONG: Catching exceptions in every controller method
@GetMapping("/{id}")
public ResponseEntity<?> getUser(@PathVariable Long id) {
    try {
        return ResponseEntity.ok(userService.getById(id));
    } catch (UserNotFoundException e) {
        // ❌ Repetitive try-catch in every endpoint
        return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
    } catch (Exception e) {
        // ❌ Inconsistent format, exposes internal message
        return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
    }
}
```

---

## Quick Reference: Conventions

### Constructor Injection (ALWAYS)

```java
// ✅ CORRECT
@Service
public class OrderService {
    private final OrderRepository orderRepository;
    private final PaymentService paymentService;
    public OrderService(OrderRepository orderRepository, PaymentService paymentService) {
        this.orderRepository = orderRepository;
        this.paymentService = paymentService;
    }
}

// ❌ WRONG: Field injection
@Autowired private OrderRepository orderRepository;   // ❌ Untestable
@Autowired private PaymentService paymentService;      // ❌ Hides dependencies
```

### Transaction Management

```java
// ✅ CORRECT: @Transactional on service methods
@Service
public class TransferService {
    @Transactional
    public void transfer(Long from, Long to, BigDecimal amount) { /* ... */ }

    @Transactional(readOnly = true)  // Read-only optimization
    public AccountResponse getAccount(Long id) { /* ... */ }
}

// ❌ WRONG
@RestController
@Transactional  // ❌ Never on controller — scope too broad
public class TransferController { }
```

### JPA Auditing

```java
// ✅ CORRECT: Auditable base entity
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class AuditableEntity {
    @CreatedDate @Column(nullable = false, updatable = false)
    private Instant createdAt;
    @LastModifiedDate @Column(nullable = false)
    private Instant updatedAt;
    @CreatedBy @Column(updatable = false)
    private String createdBy;
    @LastModifiedBy
    private String updatedBy;
    // getters/setters omitted for brevity
}
```

### Flyway Migrations

```sql
-- ✅ CORRECT: Versioned Flyway migration
-- src/main/resources/db/migration/V1__create_users_table.sql
CREATE TABLE users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255),
    avatar_url VARCHAR(500),
    google_sub VARCHAR(255) UNIQUE,
    auth_provider ENUM('LOCAL','GOOGLE') NOT NULL DEFAULT 'LOCAL',
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_email (email),
    INDEX idx_users_google_sub (google_sub)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

```yaml
# ❌ WRONG: Hibernate auto-DDL in production
spring.jpa.hibernate.ddl-auto: create-drop  # ❌ DESTROYS ALL DATA
# spring.jpa.hibernate.ddl-auto: update     # ❌ Unsafe, no rollback
```

### Testing Patterns

```java
// ✅ CORRECT: Service unit test with Mockito
@ExtendWith(MockitoExtension.class)
class UserServiceTest {
    @Mock private UserRepository userRepository;
    @Mock private UserMapper userMapper;
    @InjectMocks private UserService userService;

    @Test
    @DisplayName("getById returns UserResponse when user exists")
    void getById_existing_returnsResponse() {
        User user = new User(); user.setId(1L); user.setName("John");
        UserResponse expected = new UserResponse(1L, "John", "j@ex.com", null, Instant.now());
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        when(userMapper.toResponse(user)).thenReturn(expected);
        assertThat(userService.getById(1L)).isEqualTo(expected);
        verify(userRepository).findById(1L);
    }

    @Test
    @DisplayName("getById throws NotFoundException when not found")
    void getById_notFound_throws() {
        when(userRepository.findById(999L)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> userService.getById(999L))
                .isInstanceOf(NotFoundException.class)
                .hasMessageContaining("User not found");
    }
}
```

```java
// ✅ CORRECT: Controller test with MockMvc
@WebMvcTest(UserController.class) @Import(SecurityConfig.class)
class UserControllerTest {
    @Autowired private MockMvc mockMvc;
    @MockBean private UserService userService;
    @Autowired private ObjectMapper objectMapper;

    @Test @WithMockUser(roles = "ADMIN")
    void getUser_returns200() throws Exception {
        when(userService.getById(1L)).thenReturn(
                new UserResponse(1L, "John", "j@ex.com", null, Instant.now()));
        mockMvc.perform(get("/api/users/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("John"));
    }
}
```

```java
// ✅ CORRECT: Integration test with Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class AuthIntegrationTest {
    @Container @ServiceConnection
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0").withDatabaseName("testdb");
    @Container @ServiceConnection
    static GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine").withExposedPorts(6379);
    @Autowired private TestRestTemplate restTemplate;

    @Test
    void fullAuthFlow() {
        var reg = Map.of("name","Test","email","t@ex.com","password","SecurePass123!");
        assertThat(restTemplate.postForEntity("/api/auth/register", reg, Map.class)
                .getStatusCode()).isEqualTo(HttpStatus.CREATED);
        var login = Map.of("email","t@ex.com","password","SecurePass123!");
        ResponseEntity<Map> resp = restTemplate.postForEntity("/api/auth/login", login, Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getHeaders().get(HttpHeaders.SET_COOKIE))
                .anyMatch(c -> c.startsWith("access_token=") && c.contains("HttpOnly"));
    }
}
```

### Docker

```dockerfile
# ✅ CORRECT: Multi-stage build with security hardening
FROM gradle:8.12-jdk21 AS build
WORKDIR /app
COPY build.gradle.kts settings.gradle.kts ./
COPY gradle ./gradle
RUN gradle dependencies --no-daemon || true
COPY src ./src
RUN gradle bootJar --no-daemon -x test

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

```dockerfile
# ❌ WRONG: Single-stage, running as root
FROM eclipse-temurin:21-jdk
COPY . /app
WORKDIR /app
RUN ./gradlew bootJar
# ❌ Full JDK (3x larger), running as root, no health check
ENTRYPOINT ["java", "-jar", "build/libs/app.jar"]
```
