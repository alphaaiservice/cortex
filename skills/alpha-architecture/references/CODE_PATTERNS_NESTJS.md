# CODE_PATTERNS_NESTJS.md — NestJS/TypeScript Code Patterns

> **Language**: Node.js/NestJS | See also: [Python/FastAPI](CODE_PATTERNS_PYTHON.md) · [Java/Spring Boot](CODE_PATTERNS_SPRINGBOOT.md)
>
> Load this file on demand when writing NestJS/TypeScript backend code.

**Stack:** NestJS 11+ | Node.js 22 LTS | TypeScript strict | Prisma ORM | pnpm

---

## 1. Layer Segregation

**Controllers** — thin, delegate to services, use decorators only.

```typescript
// CORRECT ✅ — Thin controller, delegates to service
// src/modules/user/user.controller.ts
import { Controller, Get, Post, Param, Body, ParseUUIDPipe } from '@nestjs/common';
import { UserService } from './user.service';
import { UserResponseDto } from './dto/user-response.dto';
import { CreateUserDto } from './dto/create-user.dto';

// Auth handled by global APP_GUARD — no @UseGuards needed
@Controller('api/v1/users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get(':id')
  async getUser(@Param('id', ParseUUIDPipe) id: string): Promise<UserResponseDto> {
    return this.userService.getById(id);
  }

  @Post()
  async createUser(@Body() dto: CreateUserDto): Promise<UserResponseDto> {
    return this.userService.create(dto);
  }
}
```

```typescript
// WRONG ❌ — Business logic and DB access in controller
@Controller('api/v1/users')
export class UserController {
  constructor(private readonly prisma: PrismaService) {}

  @Get(':id')
  async getUser(@Param('id') id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } }); // NO! DB in controller
    if (!user) throw new NotFoundException('User not found'); // NO! Logic in controller
    const subscriptions = await this.prisma.subscription.findMany({ where: { userId: id } });
    return { ...user, isActive: subscriptions.some((s) => s.status === 'active') }; // NO!
  }
}
```

**Services** — business logic only, never import controllers or use Prisma directly.

```typescript
// CORRECT ✅ — Uses repository, pure business logic
// src/modules/user/user.service.ts
import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { UserRepository } from './user.repository';
import { UserResponseDto } from './dto/user-response.dto';
import { CreateUserDto } from './dto/create-user.dto';

@Injectable()
export class UserService {
  constructor(private readonly userRepo: UserRepository) {}

  async getById(id: string): Promise<UserResponseDto> {
    const user = await this.userRepo.findById(id);
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return UserResponseDto.fromEntity(user);
  }

  async create(dto: CreateUserDto): Promise<UserResponseDto> {
    const existing = await this.userRepo.findByEmail(dto.email);
    if (existing) {
      throw new ConflictException('Email already registered');
    }
    const user = await this.userRepo.create(dto);
    return UserResponseDto.fromEntity(user);
  }
}
```

```typescript
// WRONG ❌ — Direct Prisma usage in service
@Injectable()
export class UserService {
  constructor(private readonly prisma: PrismaService) {} // NO! Use repository

  async getById(id: string) {
    return this.prisma.user.findUnique({ where: { id } }); // NO! Direct DB access
  }
}
```

**Repositories** — pure data access, no business logic.

```typescript
// CORRECT ✅ — Pure CRUD, Prisma data access
// src/modules/user/user.repository.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { User, Prisma } from '@prisma/client';

@Injectable()
export class UserRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  async create(data: Prisma.UserCreateInput): Promise<User> {
    return this.prisma.user.create({ data });
  }

  async update(id: string, data: Prisma.UserUpdateInput): Promise<User> {
    return this.prisma.user.update({ where: { id }, data });
  }

  async delete(id: string): Promise<void> {
    await this.prisma.user.delete({ where: { id } });
  }
}
```

```typescript
// WRONG ❌ — Business logic in repository
@Injectable()
export class UserRepository {
  async getActivePremiumUsers() {
    // Complex business filtering — this belongs in UserService
    const users = await this.prisma.user.findMany({
      where: { role: 'premium', isActive: true, lastLogin: { gte: thirtyDaysAgo } },
    });
    return users.filter((u) => u.subscriptionEnd > new Date()); // NO! Business logic in repo
  }
}
```

**DTOs** — class-validator for request validation, plain classes for response mapping.

```typescript
// CORRECT ✅ — Request DTO with class-validator
// src/modules/user/dto/create-user.dto.ts
import { IsEmail, IsString, MinLength, MaxLength, IsOptional } from 'class-validator';
import { Transform } from 'class-transformer';

export class CreateUserDto {
  @IsEmail()
  @Transform(({ value }) => value?.toLowerCase().trim())
  email: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128)
  password: string;

  @IsString()
  @MinLength(2)
  @MaxLength(100)
  displayName: string;

  @IsOptional()
  @IsString()
  avatarUrl?: string;
}

// CORRECT ✅ — Response DTO with static factory
// src/modules/user/dto/user-response.dto.ts
import { Exclude, Expose } from 'class-transformer';
import { User } from '@prisma/client';

export class UserResponseDto {
  @Expose() id: string;
  @Expose() email: string;
  @Expose() displayName: string;
  @Expose() avatarUrl: string | null;
  @Expose() createdAt: Date;
  @Exclude() passwordHash: string; // Never sent to client

  static fromEntity(user: User): UserResponseDto {
    const dto = new UserResponseDto();
    dto.id = user.id;
    dto.email = user.email;
    dto.displayName = user.displayName;
    dto.avatarUrl = user.avatarUrl;
    dto.createdAt = user.createdAt;
    return dto;
  }
}
```

```typescript
// WRONG ❌ — No validation, returning raw DB entity
@Post()
async create(@Body() body: any) { // NO! Untyped, no validation
  return this.prisma.user.create({ data: body }); // NO! Leaks passwordHash
}
```

**Module wiring** — register controller, service, and repository together.

```typescript
// CORRECT ✅ — Module with proper providers
// src/modules/user/user.module.ts
import { Module } from '@nestjs/common';
import { UserController } from './user.controller';
import { UserService } from './user.service';
import { UserRepository } from './user.repository';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [UserController],
  providers: [UserService, UserRepository],
  exports: [UserService],
})
export class UserModule {}
```

---

## 2. Auth Implementation — JWT + HTTP-Only Cookies

```typescript
// CORRECT ✅ — JWT Strategy extracting token from HTTP-Only cookie
// src/common/auth/strategies/jwt.strategy.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { Request } from 'express';
import { UserRepository } from '../../../modules/user/user.repository';

const cookieExtractor = (req: Request): string | null => {
  return req?.cookies?.access_token ?? null;
};

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    private readonly config: ConfigService,
    private readonly userRepo: UserRepository,
  ) {
    super({
      jwtFromRequest: cookieExtractor, // FROM COOKIE, never Authorization header
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>('JWT_SECRET'),
    });
  }

  async validate(payload: { sub: string; email: string }) {
    const user = await this.userRepo.findById(payload.sub);
    if (!user) {
      throw new UnauthorizedException('User no longer exists');
    }
    return user; // Attached to request.user
  }
}
```

```typescript
// WRONG ❌ — Extracting JWT from Authorization header
import { ExtractJwt } from 'passport-jwt';

super({
  jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(), // NO! Use cookie
  secretOrKey: config.get('JWT_SECRET'),
});
```

```typescript
// CORRECT ✅ — Auth service with cookie-based token management
// src/modules/auth/auth.service.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { Response } from 'express';
import { UserRepository } from '../user/user.repository';
import { UserResponseDto } from '../user/dto/user-response.dto';
import { RedisService } from '../../common/redis/redis.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    private readonly userRepo: UserRepository,
    private readonly redis: RedisService,
  ) {}

  async login(email: string, password: string, res: Response) {
    const user = await this.userRepo.findByEmail(email);
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }
    this.setAuthCookies(res, user.id, user.email);
    return { user: UserResponseDto.fromEntity(user) };
  }

  async logout(userId: string, accessToken: string, res: Response) {
    // Blacklist current access token in Redis
    const decoded = this.jwtService.decode(accessToken) as { exp: number };
    const ttl = decoded.exp - Math.floor(Date.now() / 1000);
    if (ttl > 0) {
      await this.redis.set(`blacklist:${accessToken}`, '1', ttl);
    }
    this.clearAuthCookies(res);
  }

  setAuthCookies(res: Response, userId: string, email: string) {
    const accessToken = this.jwtService.sign(
      { sub: userId, email },
      { expiresIn: '30m' },
    );
    const refreshToken = this.jwtService.sign(
      { sub: userId, type: 'refresh' },
      { expiresIn: '7d', secret: this.config.getOrThrow('JWT_REFRESH_SECRET') },
    );

    const cookieOptions = {
      httpOnly: true,
      secure: this.config.get('NODE_ENV') === 'production',
      sameSite: 'lax' as const,
      path: '/',
    };

    res.cookie('access_token', accessToken, { ...cookieOptions, maxAge: 30 * 60 * 1000 });
    res.cookie('refresh_token', refreshToken, {
      ...cookieOptions,
      maxAge: 7 * 24 * 60 * 60 * 1000,
      path: '/api/auth/refresh',
    });
  }

  clearAuthCookies(res: Response) {
    res.clearCookie('access_token', { path: '/' });
    res.clearCookie('refresh_token', { path: '/api/auth/refresh' });
  }
}
```

```typescript
// WRONG ❌ — Returning token in response body
async login(email: string, password: string) {
  const token = this.jwtService.sign({ sub: user.id });
  return { access_token: token }; // NO! Client stores in localStorage — XSS risk
}
```

```typescript
// CORRECT ✅ — JWT Auth Guard with blacklist check
// src/common/guards/jwt-auth.guard.ts
import { Injectable, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { RedisService } from '../redis/redis.service';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly redis: RedisService) {
    super();
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const result = await (super.canActivate(context) as Promise<boolean>);
    if (!result) return false;

    // Check token blacklist
    const request = context.switchToHttp().getRequest();
    const token = request.cookies?.access_token;
    if (token) {
      const isBlacklisted = await this.redis.get(`blacklist:${token}`);
      if (isBlacklisted) {
        throw new UnauthorizedException('Token has been revoked');
      }
    }

    return true;
  }
}
```

### Global Auth Guard Registration (HARD RULE)

```
# ┌─────────────────────────────────────────────────────────────────┐
# │  HARD RULE: ALL auth verification happens via GLOBAL GUARD —   │
# │  NEVER via per-controller @UseGuards(JwtAuthGuard).            │
# │  ❌ NEVER: @UseGuards(JwtAuthGuard) on controllers/methods     │
# │  ❌ NEVER: manual token checking in controllers                │
# │  ✅ ALWAYS: APP_GUARD global registration in AppModule         │
# │  ✅ ALWAYS: @Public() decorator for unauthenticated routes     │
# │  ✅ ALWAYS: @CurrentUser() to access user in controllers       │
# └─────────────────────────────────────────────────────────────────┘
```

```typescript
// CORRECT ✅ — @Public() decorator for exempt routes
// src/common/decorators/public.decorator.ts
import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
```

```typescript
// CORRECT ✅ — JwtAuthGuard with @Public() support (GLOBAL guard)
// src/common/guards/jwt-auth.guard.ts
import { Injectable, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Reflector } from '@nestjs/core';
import { RedisService } from '../redis/redis.service';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(
    private readonly reflector: Reflector,
    private readonly redis: RedisService,
  ) {
    super();
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // Check if route is marked @Public() — skip auth
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    // Validate JWT via Passport strategy
    const result = await (super.canActivate(context) as Promise<boolean>);
    if (!result) return false;

    // Check token blacklist (logout support)
    const request = context.switchToHttp().getRequest();
    const token = request.cookies?.access_token;
    if (token) {
      const isBlacklisted = await this.redis.get(`blacklist:${token}`);
      if (isBlacklisted) {
        throw new UnauthorizedException('Token has been revoked');
      }
    }

    return true;
  }
}
```

```typescript
// CORRECT ✅ — Register JwtAuthGuard globally in AppModule
// src/app.module.ts
import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { PermissionsGuard } from './common/guards/permissions.guard';

@Module({
  providers: [
    // Global auth guard — ALL routes protected by default
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    // Global permissions guard — checks @RequirePermissions() decorator
    { provide: APP_GUARD, useClass: PermissionsGuard },
  ],
})
export class AppModule {}
```

```typescript
// WRONG ❌ — Per-controller guard (NEVER do this)
@Controller('api/v1/users')
@UseGuards(JwtAuthGuard)  // ❌ NO! JwtAuthGuard is registered globally via APP_GUARD
export class UserController { ... }

// CORRECT ✅ — No @UseGuards needed, global guard handles it
@Controller('api/v1/users')
export class UserController {
  @Get(':id')
  async getUser(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    // Auth already handled by global JwtAuthGuard
    return this.userService.getById(id);
  }
}

// CORRECT ✅ — Public routes use @Public() decorator
@Controller('api/auth')
export class AuthController {
  @Public()
  @Post('login')
  async login(@Body() dto: LoginDto, @Res() res: Response) { ... }

  @Public()
  @Post('register')
  async register(@Body() dto: RegisterDto, @Res() res: Response) { ... }

  @Public()
  @Get('google')
  @UseGuards(AuthGuard('google'))  // This is OK — Google OAuth strategy, not JwtAuthGuard
  async googleLogin() { ... }
}
```

```typescript
// CORRECT ✅ — CurrentUser decorator
// src/common/decorators/current-user.decorator.ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const CurrentUser = createParamDecorator(
  (data: string | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user = request.user;
    return data ? user?.[data] : user;
  },
);

// Usage in controller:
// Auth handled by global guard — just use @CurrentUser()
@Get('profile')
async getProfile(@CurrentUser() user: User) {
  return this.userService.getProfile(user.id);
}

// Auth handled by global guard — just use @CurrentUser()
@Get('my-id')
async getMyId(@CurrentUser('id') userId: string) {
  return { userId };
}
```

---

## 3. Google OAuth2 — Passport Google Strategy

```typescript
// CORRECT ✅ — Server-side OAuth2 Authorization Code Grant
// src/common/auth/strategies/google.strategy.ts
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, VerifyCallback, Profile } from 'passport-google-oauth20';
import { ConfigService } from '@nestjs/config';
import { AuthService } from '../../../modules/auth/auth.service';

@Injectable()
export class GoogleStrategy extends PassportStrategy(Strategy, 'google') {
  constructor(
    private readonly config: ConfigService,
    private readonly authService: AuthService,
  ) {
    super({
      clientID: config.getOrThrow('GOOGLE_CLIENT_ID'),
      clientSecret: config.getOrThrow('GOOGLE_CLIENT_SECRET'),
      callbackURL: config.getOrThrow('GOOGLE_CALLBACK_URL'),
      scope: ['email', 'profile'],
    });
  }

  async validate(
    accessToken: string,
    refreshToken: string,
    profile: Profile,
    done: VerifyCallback,
  ) {
    const user = await this.authService.googleLoginOrRegister({
      email: profile.emails![0].value,
      displayName: profile.displayName,
      avatarUrl: profile.photos?.[0]?.value ?? null,
      googleId: profile.id,
    });
    done(null, user);
  }
}
```

```typescript
// CORRECT ✅ — Google OAuth controller with cookie-based response
// src/modules/auth/auth.controller.ts
import { Controller, Get, Req, Res, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Request, Response } from 'express';
import { ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { User } from '@prisma/client';

@Controller('api/auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly config: ConfigService,
  ) {}

  @Get('google')
  @UseGuards(AuthGuard('google'))
  async googleLogin() {
    // Passport redirects to Google — this method body is never reached
  }

  @Get('google/callback')
  @UseGuards(AuthGuard('google'))
  async googleCallback(@Req() req: Request, @Res() res: Response) {
    const user = req.user as User;
    this.authService.setAuthCookies(res, user.id, user.email);
    res.redirect(this.config.getOrThrow('FRONTEND_URL') + '/dashboard');
  }
}
```

```typescript
// WRONG ❌ — Client-side Google token validation
@Post('google')
async googleLogin(@Body('idToken') idToken: string) {
  const ticket = await client.verifyIdToken({ idToken }); // NO! Use server-side flow
  const payload = ticket.getPayload();
  const token = this.jwtService.sign({ sub: payload.sub });
  return { access_token: token }; // NO! Use HTTP-Only cookies
}
```

---

## 4. Email Sending — @nestjs-modules/mailer + BullMQ

```typescript
// CORRECT ✅ — Async email via BullMQ queue
// src/modules/email/email.module.ts
import { Module } from '@nestjs/common';
import { MailerModule } from '@nestjs-modules/mailer';
import { HandlebarsAdapter } from '@nestjs-modules/mailer/dist/adapters/handlebars.adapter';
import { BullModule } from '@nestjs/bullmq';
import { ConfigService } from '@nestjs/config';
import { EmailService } from './email.service';
import { EmailProcessor } from './email.processor';
import { join } from 'path';

@Module({
  imports: [
    BullModule.registerQueue({ name: 'email' }),
    MailerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        transport: {
          host: config.getOrThrow('SMTP_HOST'),
          port: config.get<number>('SMTP_PORT', 587),
          auth: {
            user: config.getOrThrow('SMTP_USER'),
            pass: config.getOrThrow('SMTP_PASS'),
          },
        },
        defaults: { from: `"Alpha AI" <${config.get('SMTP_FROM')}>` },
        template: {
          dir: join(__dirname, 'templates'),
          adapter: new HandlebarsAdapter(),
          options: { strict: true },
        },
      }),
    }),
  ],
  providers: [EmailService, EmailProcessor],
  exports: [EmailService],
})
export class EmailModule {}
```

```typescript
// CORRECT ✅ — Email service queues emails, never sends directly
// src/modules/email/email.service.ts
import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

export interface EmailJob {
  to: string;
  subject: string;
  template: string;
  context: Record<string, unknown>;
}

@Injectable()
export class EmailService {
  constructor(@InjectQueue('email') private readonly emailQueue: Queue) {}

  async sendWelcome(email: string, displayName: string) {
    await this.emailQueue.add('send', {
      to: email,
      subject: 'Welcome to Alpha AI!',
      template: 'welcome',
      context: { name: displayName },
    });
  }

  async sendOtp(email: string, otp: string) {
    await this.emailQueue.add(
      'send',
      {
        to: email,
        subject: `Your OTP: ${otp}`,
        template: 'verify-otp',
        context: { otp, expiryMinutes: 5 },
      },
      { attempts: 3, backoff: { type: 'exponential', delay: 2000 } },
    );
  }

  async sendPasswordReset(email: string, resetLink: string) {
    await this.emailQueue.add('send', {
      to: email,
      subject: 'Reset Your Password',
      template: 'password-reset',
      context: { resetLink, expiryMinutes: 30 },
    });
  }
}
```

```typescript
// CORRECT ✅ — BullMQ processor handles actual sending
// src/modules/email/email.processor.ts
import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { MailerService } from '@nestjs-modules/mailer';
import { Logger } from '@nestjs/common';
import { EmailJob } from './email.service';

@Processor('email')
export class EmailProcessor extends WorkerHost {
  private readonly logger = new Logger(EmailProcessor.name);

  constructor(private readonly mailer: MailerService) {
    super();
  }

  async process(job: Job<EmailJob>): Promise<void> {
    const { to, subject, template, context } = job.data;
    this.logger.log(`Sending email to ${to} — template: ${template}`);

    await this.mailer.sendMail({
      to,
      subject,
      template,
      context,
    });

    this.logger.log(`Email sent successfully to ${to}`);
  }
}
```

```typescript
// WRONG ❌ — Blocking email send in controller
@Post('register')
async register(@Body() dto: RegisterDto, @Res() res: Response) {
  const user = await this.authService.register(dto);
  await this.mailerService.sendMail({ // NO! Blocks API response for 2-5 seconds
    to: user.email,
    subject: 'Welcome!',
    template: 'welcome',
    context: { name: user.displayName },
  });
  return user;
}
```

---

## 5. RBAC — Roles Guard + Permissions Decorator

```typescript
// CORRECT ✅ — Permission-based RBAC with decorator + guard
// src/common/decorators/permissions.decorator.ts
import { SetMetadata } from '@nestjs/common';

export const PERMISSIONS_KEY = 'permissions';
export const RequirePermissions = (...permissions: string[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);
```

```typescript
// CORRECT ✅ — Permissions guard checks granular permissions
// src/common/guards/permissions.guard.ts
import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    // Skip permissions check if route is marked @Public()
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(), context.getClass(),
    ]);
    if (isPublic) return true;

    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredPermissions || requiredPermissions.length === 0) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();
    if (!user?.permissions) {
      throw new ForbiddenException('No permissions assigned');
    }

    const hasAll = requiredPermissions.every((perm) =>
      user.permissions.includes(perm),
    );

    if (!hasAll) {
      throw new ForbiddenException(
        `Missing permissions: ${requiredPermissions.filter((p) => !user.permissions.includes(p)).join(', ')}`,
      );
    }

    return true;
  }
}
```

```typescript
// CORRECT ✅ — Controller using RBAC
// Auth + Permissions handled by global APP_GUARD — no @UseGuards needed
@Controller('api/v1/admin/users')
export class AdminUserController {
  constructor(private readonly adminService: AdminService) {}

  @Delete(':id')
  @RequirePermissions('users:delete')
  async deleteUser(@Param('id', ParseUUIDPipe) id: string) {
    return this.adminService.deleteUser(id);
  }

  @Patch(':id/role')
  @RequirePermissions('users:update', 'roles:assign')
  async updateRole(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateRoleDto,
  ) {
    return this.adminService.updateUserRole(id, dto.role);
  }
}
```

```typescript
// WRONG ❌ — Simple role string comparison
@Delete(':id')
async deleteUser(@Param('id') id: string, @Req() req: Request) {
  if (req.user.role !== 'admin') { // NO! Use granular permissions
    throw new ForbiddenException();
  }
  return this.adminService.deleteUser(id);
}
```

---

## 6. File Upload — Presigned URL Pattern with AWS S3 SDK v3

```typescript
// CORRECT ✅ — Presigned URL generation, frontend uploads directly to S3
// src/modules/storage/storage.service.ts
import { Injectable } from '@nestjs/common';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { ConfigService } from '@nestjs/config';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class StorageService {
  private readonly s3: S3Client;
  private readonly bucket: string;

  constructor(private readonly config: ConfigService) {
    this.s3 = new S3Client({
      region: config.getOrThrow('AWS_REGION'),
      credentials: {
        accessKeyId: config.getOrThrow('AWS_ACCESS_KEY_ID'),
        secretAccessKey: config.getOrThrow('AWS_SECRET_ACCESS_KEY'),
      },
    });
    this.bucket = config.getOrThrow('S3_BUCKET');
  }

  async generateUploadUrl(
    userId: string,
    filename: string,
    contentType: string,
  ): Promise<{ uploadUrl: string; fileKey: string }> {
    const fileKey = `uploads/${userId}/${uuidv4()}/${filename}`;

    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: fileKey,
      ContentType: contentType,
    });

    const uploadUrl = await getSignedUrl(this.s3, command, { expiresIn: 3600 });

    return { uploadUrl, fileKey };
  }

  async generateDownloadUrl(fileKey: string): Promise<string> {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: fileKey,
    });

    return getSignedUrl(this.s3, command, { expiresIn: 3600 });
  }
}
```

```typescript
// CORRECT ✅ — Controller returns presigned URL
// src/modules/storage/storage.controller.ts
import { Controller, Post, Body } from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { StorageService } from './storage.service';
import { PresignedUrlDto } from './dto/presigned-url.dto';

// Auth handled by global APP_GUARD — no @UseGuards needed
@Controller('api/v1/upload')
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  @Post('presigned-url')
  async getPresignedUrl(
    @CurrentUser('id') userId: string,
    @Body() dto: PresignedUrlDto,
  ) {
    return this.storageService.generateUploadUrl(
      userId,
      dto.filename,
      dto.contentType,
    );
  }
}
```

```typescript
// WRONG ❌ — Accepting file upload in API body (blocks server, memory issues)
@Post('upload')
@UseInterceptors(FileInterceptor('file'))
async upload(@UploadedFile() file: Express.Multer.File) { // NO! Use presigned URLs
  const buffer = file.buffer; // NO! Entire file in memory
  await this.s3.send(new PutObjectCommand({
    Bucket: this.bucket,
    Key: `uploads/${file.originalname}`,
    Body: buffer, // NO! Blocks server, memory issues on large files
  }));
}
```

---

## 7. Point Deduction — Credit Points Billing (Prisma + Redis)

```typescript
// CORRECT ✅ — Points decorator and guard
// src/common/decorators/points.decorator.ts
import { SetMetadata } from '@nestjs/common';

export const POINTS_COST_KEY = 'points_cost';
export const RequirePoints = (cost: number) => SetMetadata(POINTS_COST_KEY, cost);
```

```typescript
// CORRECT ✅ — Points guard checks and deducts credits
// src/common/guards/points.guard.ts
import {
  Injectable, CanActivate, ExecutionContext,
  HttpException, HttpStatus,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { POINTS_COST_KEY } from '../decorators/points.decorator';
import { PointService } from '../../modules/point/point.service';

@Injectable()
export class PointsGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly pointService: PointService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const cost = this.reflector.get<number>(POINTS_COST_KEY, context.getHandler());
    if (!cost) return true;

    const request = context.switchToHttp().getRequest();
    const userId = request.user?.id;
    if (!userId) return false;

    const balance = await this.pointService.getBalance(userId);
    if (balance < cost) {
      const topupPacks = await this.pointService.getTopupPacks();
      throw new HttpException(
        {
          error: 'insufficient_points',
          required: cost,
          balance,
          topupPacks,
        },
        HttpStatus.PAYMENT_REQUIRED,
      );
    }

    await this.pointService.deduct(userId, cost, 'ai_generation');
    request.pointsDeducted = cost;
    return true;
  }
}
```

```typescript
// CORRECT ✅ — Point service with Prisma transaction + Redis cache
// src/modules/point/point.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../common/redis/redis.service';

@Injectable()
export class PointService {
  private readonly logger = new Logger(PointService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  async getBalance(userId: string): Promise<number> {
    const cached = await this.redis.get(`points:${userId}`);
    if (cached !== null) return parseInt(cached, 10);

    const wallet = await this.prisma.pointWallet.findUnique({
      where: { userId },
    });
    const balance = wallet?.balance ?? 0;
    await this.redis.set(`points:${userId}`, balance.toString(), 300);
    return balance;
  }

  async deduct(userId: string, amount: number, action: string): Promise<number> {
    const result = await this.prisma.$transaction(async (tx) => {
      const wallet = await tx.pointWallet.update({
        where: { userId },
        data: { balance: { decrement: amount } },
      });

      await tx.pointTransaction.create({
        data: {
          userId,
          amount: -amount,
          action,
          balanceAfter: wallet.balance,
        },
      });

      return wallet.balance;
    });

    await this.redis.set(`points:${userId}`, result.toString(), 300);
    this.logger.log(`Deducted ${amount} points from user ${userId}. Balance: ${result}`);
    return result;
  }

  async getTopupPacks() {
    return [
      { id: 'starter', points: 100, priceInr: 99 },
      { id: 'pro', points: 500, priceInr: 399 },
      { id: 'enterprise', points: 2000, priceInr: 1299 },
    ];
  }
}
```

```typescript
// CORRECT ✅ — Controller using RequirePoints decorator
// Auth + Points handled by global APP_GUARD — no @UseGuards needed
@Controller('api/v1/ai')
export class AiController {
  @Post('generate')
  @RequirePoints(10)
  async generate(@Body() dto: GenerateDto, @CurrentUser() user: User) {
    return this.aiService.generate(dto, user.id);
  }
}
```

```typescript
// WRONG ❌ — No point check on GenAI endpoint
@Post('generate')
async generate(@Body() dto: GenerateDto, @CurrentUser() user: User) {
  return this.aiService.generate(dto, user.id); // NO! No point gate = cost leak
}
```

---

## 8. Webhook Verification — Razorpay HMAC SHA256

```typescript
// CORRECT ✅ — Verify Razorpay signature, deduplicate, process async
// src/modules/webhook/webhook.controller.ts
import { Controller, Post, Req, Headers, HttpCode, Logger } from '@nestjs/common';
import { Request } from 'express';
import { WebhookService } from './webhook.service';

@Controller('api/webhooks')
export class WebhookController {
  private readonly logger = new Logger(WebhookController.name);

  constructor(private readonly webhookService: WebhookService) {}

  @Post('razorpay')
  @HttpCode(200)
  async razorpayWebhook(
    @Req() req: Request,
    @Headers('x-razorpay-signature') signature: string,
  ) {
    const rawBody = (req as any).rawBody as Buffer; // Needs raw body middleware
    this.webhookService.verifyRazorpaySignature(rawBody, signature);

    const event = JSON.parse(rawBody.toString());
    const eventId = event.event_id ?? event.id;

    // Idempotency check
    const alreadyProcessed = await this.webhookService.isDuplicate(eventId);
    if (alreadyProcessed) {
      this.logger.warn(`Duplicate webhook event: ${eventId}`);
      return { status: 'already_processed' };
    }

    // Process async via BullMQ
    await this.webhookService.enqueueWebhookEvent(event);
    return { status: 'ok' };
  }
}
```

```typescript
// CORRECT ✅ — Webhook service with HMAC verification
// src/modules/webhook/webhook.service.ts
import { Injectable, UnauthorizedException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { createHmac } from 'crypto';
import { RedisService } from '../../common/redis/redis.service';

@Injectable()
export class WebhookService {
  private readonly logger = new Logger(WebhookService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly redis: RedisService,
    @InjectQueue('webhook') private readonly webhookQueue: Queue,
  ) {}

  verifyRazorpaySignature(rawBody: Buffer, signature: string): void {
    const secret = this.config.getOrThrow('RAZORPAY_WEBHOOK_SECRET');
    const expectedSignature = createHmac('sha256', secret)
      .update(rawBody)
      .digest('hex');

    if (expectedSignature !== signature) {
      this.logger.error('Invalid Razorpay webhook signature');
      throw new UnauthorizedException('Invalid webhook signature');
    }
  }

  async isDuplicate(eventId: string): Promise<boolean> {
    const exists = await this.redis.get(`rzp_webhook:${eventId}`);
    if (exists) return true;
    await this.redis.set(`rzp_webhook:${eventId}`, '1', 172800); // 48h TTL
    return false;
  }

  async enqueueWebhookEvent(event: Record<string, unknown>) {
    await this.webhookQueue.add('process', event, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 5000 },
    });
  }
}
```

```typescript
// WRONG ❌ — No signature verification, synchronous processing
@Post('razorpay')
async razorpayWebhook(@Body() body: any) { // NO! No raw body for HMAC
  // NO signature verification! Anyone can call this endpoint
  await this.paymentService.processPayment(body); // NO! Blocks, no retry, no idempotency
  return { status: 'ok' };
}
```

---

## 9. GenAI Gateway — Vercel AI SDK + Model Registry

```typescript
// CORRECT ✅ — Unified AI gateway with model registry and fallbacks
// src/modules/ai/ai-gateway.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { createOpenAI } from '@ai-sdk/openai';
import { createAnthropic } from '@ai-sdk/anthropic';
import { generateText, streamText, LanguageModel } from 'ai';
import { ConfigService } from '@nestjs/config';

type ModelTier = 'fast' | 'smart' | 'premium' | 'local';

@Injectable()
export class AiGatewayService {
  private readonly logger = new Logger(AiGatewayService.name);
  private readonly openai: ReturnType<typeof createOpenAI>;
  private readonly anthropic: ReturnType<typeof createAnthropic>;

  private readonly modelRegistry: Record<ModelTier, () => LanguageModel> = {
    fast: () => this.openai('gpt-4o-mini'),
    smart: () => this.anthropic('claude-sonnet-4-6'),
    premium: () => this.anthropic('claude-opus-4-6'),
    local: () => this.openai('gpt-4o'), // Fallback for local-tier
  };

  constructor(private readonly config: ConfigService) {
    this.openai = createOpenAI({
      apiKey: config.getOrThrow('OPENAI_API_KEY'),
    });
    this.anthropic = createAnthropic({
      apiKey: config.getOrThrow('ANTHROPIC_API_KEY'),
    });
  }

  getModel(tier: ModelTier = 'smart'): LanguageModel {
    const factory = this.modelRegistry[tier];
    if (!factory) {
      this.logger.warn(`Unknown model tier: ${tier}, falling back to smart`);
      return this.modelRegistry.smart();
    }
    return factory();
  }

  async generate(
    prompt: string,
    options: { tier?: ModelTier; system?: string; maxTokens?: number } = {},
  ) {
    const model = this.getModel(options.tier);
    return generateText({
      model,
      system: options.system,
      prompt,
      maxTokens: options.maxTokens ?? 4096,
    });
  }

  async *stream(
    prompt: string,
    options: { tier?: ModelTier; system?: string; maxTokens?: number } = {},
  ) {
    const model = this.getModel(options.tier);
    const result = streamText({
      model,
      system: options.system,
      prompt,
      maxTokens: options.maxTokens ?? 4096,
    });

    for await (const chunk of result.textStream) {
      yield chunk;
    }
  }
}
```

```typescript
// WRONG ❌ — Direct provider SDK, locked to one LLM
import OpenAI from 'openai';

const openai = new OpenAI(); // NO! Provider lock-in
const response = await openai.chat.completions.create({
  model: 'gpt-4o',
  messages: [{ role: 'user', content: prompt }],
}); // NO! Cannot switch providers without rewriting code
```

---

## 10. RAG Retrieval — Qdrant Vector Search + Embedding

```typescript
// CORRECT ✅ — Hybrid retrieval with vector search
// src/modules/ai/rag/retriever.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { QdrantClient } from '@qdrant/js-client-rest';
import { ConfigService } from '@nestjs/config';
import { embed } from 'ai';
import { createOpenAI } from '@ai-sdk/openai';

export interface RetrievalResult {
  text: string;
  score: number;
  metadata: Record<string, unknown>;
}

@Injectable()
export class RetrieverService {
  private readonly logger = new Logger(RetrieverService.name);
  private readonly qdrant: QdrantClient;
  private readonly embeddingModel;

  constructor(private readonly config: ConfigService) {
    this.qdrant = new QdrantClient({
      url: config.getOrThrow('QDRANT_URL'),
      apiKey: config.get('QDRANT_API_KEY'),
    });
    const openai = createOpenAI({ apiKey: config.getOrThrow('OPENAI_API_KEY') });
    this.embeddingModel = openai.embedding('text-embedding-3-large');
  }

  async retrieve(
    query: string,
    collectionName: string = 'documents',
    topK: number = 5,
  ): Promise<RetrievalResult[]> {
    const { embedding } = await embed({
      model: this.embeddingModel,
      value: query,
    });

    const results = await this.qdrant.search(collectionName, {
      vector: embedding,
      limit: topK,
      with_payload: true,
    });

    return results.map((r) => ({
      text: r.payload?.text as string,
      score: r.score,
      metadata: r.payload as Record<string, unknown>,
    }));
  }

  async upsertDocument(
    collectionName: string,
    id: string,
    text: string,
    metadata: Record<string, unknown> = {},
  ) {
    const { embedding } = await embed({
      model: this.embeddingModel,
      value: text,
    });

    await this.qdrant.upsert(collectionName, {
      points: [
        {
          id,
          vector: embedding,
          payload: { text, ...metadata, indexedAt: new Date().toISOString() },
        },
      ],
    });
  }
}
```

```typescript
// WRONG ❌ — Stuffing full documents into context
const allDocs = await this.prisma.document.findMany();
const fullText = allDocs.map((d) => d.content).join('\n');
const response = await generateText({
  model,
  prompt: `${fullText}\n\nQuestion: ${query}`, // NO! Token waste, context overflow
});
```

---

## 11. AI Streaming — Server-Sent Events (SSE)

```typescript
// CORRECT ✅ — SSE streaming for AI chat responses
// src/modules/ai/ai.controller.ts
import { Controller, Post, Body, Res } from '@nestjs/common';
import { Response } from 'express';
import { AiGatewayService } from './ai-gateway.service';
import { ChatDto } from './dto/chat.dto';

// Auth handled by global APP_GUARD — no @UseGuards needed
@Controller('api/v1/ai')
export class AiController {
  constructor(private readonly aiGateway: AiGatewayService) {}

  @Post('chat')
  async chat(@Body() dto: ChatDto, @Res() res: Response) {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');

    try {
      for await (const chunk of this.aiGateway.stream(dto.message, {
        tier: dto.modelTier,
        system: dto.systemPrompt,
      })) {
        if (chunk) {
          res.write(`data: ${JSON.stringify({ content: chunk })}\n\n`);
        }
      }
      res.write('data: [DONE]\n\n');
    } catch (error) {
      res.write(`data: ${JSON.stringify({ error: 'Stream failed' })}\n\n`);
    } finally {
      res.end();
    }
  }
}
```

```typescript
// WRONG ❌ — Waiting for full AI response before returning
@Post('chat')
async chat(@Body() dto: ChatDto) {
  const result = await this.aiGateway.generate(dto.message); // Blocks for 5-30 seconds
  return { text: result.text }; // NO! Stream it for responsive UX
}
```

---

## 12. MCP Prompt Server — TypeScript Implementation

```typescript
// CORRECT ✅ — MCP server exposing reusable prompts and tools
// src/modules/mcp/mcp-server.ts
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { readFile } from 'fs/promises';
import { join } from 'path';
import Handlebars from 'handlebars';

const server = new McpServer({
  name: 'alpha-ai-prompts',
  version: '1.0.0',
});

// Register prompts
server.prompt(
  'code-review',
  'Analyze code quality and suggest improvements',
  {
    code: z.string().describe('Code to review'),
    language: z.string().optional().describe('Programming language'),
  },
  async ({ code, language }) => {
    const templateSource = await readFile(
      join(__dirname, 'templates', 'code-review.hbs'),
      'utf-8',
    );
    const template = Handlebars.compile(templateSource);
    const rendered = template({ code, language: language ?? 'auto-detect' });

    return {
      messages: [
        { role: 'user' as const, content: { type: 'text' as const, text: rendered } },
      ],
    };
  },
);

server.prompt(
  'summarize-document',
  'Generate concise summary of a document',
  {
    content: z.string().describe('Document content'),
    maxLength: z.number().optional().describe('Max summary length in words'),
  },
  async ({ content, maxLength }) => ({
    messages: [
      {
        role: 'user' as const,
        content: {
          type: 'text' as const,
          text: `Summarize the following document${maxLength ? ` in no more than ${maxLength} words` : ''}:\n\n${content}`,
        },
      },
    ],
  }),
);

// Register tools
server.tool(
  'search-knowledge-base',
  'Search the knowledge base for relevant documents',
  {
    query: z.string().describe('Search query'),
    limit: z.number().optional().default(5).describe('Max results'),
  },
  async ({ query, limit }) => {
    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify({ query, limit, results: [] }),
        },
      ],
    };
  },
);

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch(console.error);
```

```typescript
// WRONG ❌ — Hardcoded prompts without MCP standard
const PROMPTS = {
  codeReview: 'Review this code: ${code}', // NO! Not discoverable, not standard
};

async function getPrompt(name: string, args: any) {
  return PROMPTS[name].replace('${code}', args.code); // NO! Use MCP protocol
}
```

---

## 13. A2A Agent Card — Discovery Endpoint

```typescript
// CORRECT ✅ — Agent Card at /.well-known/agent.json
// src/modules/a2a/a2a.controller.ts
import { Controller, Get, Header } from '@nestjs/common';

const AGENT_CARD = {
  name: 'alpha-ai-assistant',
  description: "Alpha AI's intelligent assistant with RAG, code generation, and analysis",
  url: 'https://api.example.com/a2a',
  version: '1.0.0',
  capabilities: {
    streaming: true,
    pushNotifications: false,
    stateTransitionHistory: true,
  },
  skills: [
    {
      id: 'document-analysis',
      name: 'Document Analysis',
      description: 'Analyze and extract insights from uploaded documents using RAG',
      tags: ['rag', 'analysis', 'documents'],
      examples: ['Summarize this PDF', 'Extract key points from the document'],
    },
    {
      id: 'code-generation',
      name: 'Code Generation',
      description: 'Generate code based on natural language descriptions',
      tags: ['code', 'generation', 'development'],
      examples: ['Write a REST API for user management', 'Create a React component'],
    },
  ],
  defaultInputModes: ['text/plain', 'application/json'],
  defaultOutputModes: ['text/plain', 'application/json'],
  authentication: {
    schemes: ['bearer'],
  },
};

@Controller('.well-known')
export class A2AController {
  @Get('agent.json')
  @Header('Content-Type', 'application/json')
  @Header('Cache-Control', 'public, max-age=3600')
  getAgentCard() {
    return AGENT_CARD;
  }
}
```

```typescript
// WRONG ❌ — No discovery endpoint, capabilities undocumented
// Agent capabilities are hardcoded and not discoverable by other agents
// NO /.well-known/agent.json endpoint — breaks A2A interoperability
```

---

## 14. Structured Output — Zod Schema Validation for LLM Output

```typescript
// CORRECT ✅ — Zod-validated LLM output with Vercel AI SDK
// src/modules/ai/structured/extractor.service.ts
import { Injectable } from '@nestjs/common';
import { generateObject } from 'ai';
import { z } from 'zod';
import { AiGatewayService } from '../ai-gateway.service';

const ProductReviewSchema = z.object({
  sentiment: z.enum(['positive', 'negative', 'neutral']),
  score: z.number().min(0).max(1),
  keyPoints: z.array(z.string()).min(1).max(10),
  summary: z.string().max(500),
  categories: z.array(z.string()),
});

type ProductReview = z.infer<typeof ProductReviewSchema>;

const InvoiceSchema = z.object({
  invoiceNumber: z.string(),
  date: z.string(),
  vendor: z.object({
    name: z.string(),
    address: z.string().optional(),
  }),
  lineItems: z.array(
    z.object({
      description: z.string(),
      quantity: z.number(),
      unitPrice: z.number(),
      total: z.number(),
    }),
  ),
  totalAmount: z.number(),
  currency: z.string().default('INR'),
});

type Invoice = z.infer<typeof InvoiceSchema>;

@Injectable()
export class ExtractorService {
  constructor(private readonly aiGateway: AiGatewayService) {}

  async extractReview(text: string): Promise<ProductReview> {
    const { object } = await generateObject({
      model: this.aiGateway.getModel('smart'),
      schema: ProductReviewSchema,
      prompt: `Analyze this product review and extract structured data:\n\n${text}`,
    });
    return object;
  }

  async extractInvoice(text: string): Promise<Invoice> {
    const { object } = await generateObject({
      model: this.aiGateway.getModel('smart'),
      schema: InvoiceSchema,
      prompt: `Extract invoice details from this text:\n\n${text}`,
    });
    return object;
  }
}
```

```typescript
// WRONG ❌ — Parsing raw text with regex
async extractReview(text: string) {
  const result = await generateText({ model, prompt: `Analyze: ${text}` });
  const sentiment = result.text.match(/sentiment:\s*(\w+)/)?.[1]; // NO! Fragile regex
  const score = parseFloat(result.text.match(/score:\s*([\d.]+)/)?.[1] ?? '0'); // NO!
  return { sentiment, score }; // NO! Use structured output with Zod schema
}
```

---

## 15. Semantic Caching — Redis + Embedding Cosine Similarity

```typescript
// CORRECT ✅ — Semantic cache with cosine similarity
// src/modules/ai/cache/semantic-cache.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { RedisService } from '../../../common/redis/redis.service';
import { embed } from 'ai';
import { createOpenAI } from '@ai-sdk/openai';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';

const CACHE_THRESHOLD = 0.95;
const CACHE_TTL_SECONDS = 86400; // 24h

@Injectable()
export class SemanticCacheService {
  private readonly logger = new Logger(SemanticCacheService.name);
  private readonly embeddingModel;

  constructor(
    private readonly redis: RedisService,
    private readonly config: ConfigService,
  ) {
    const openai = createOpenAI({ apiKey: config.getOrThrow('OPENAI_API_KEY') });
    this.embeddingModel = openai.embedding('text-embedding-3-large');
  }

  private cosineSimilarity(a: number[], b: number[]): number {
    let dotProduct = 0;
    let normA = 0;
    let normB = 0;
    for (let i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
  }

  async getCachedResponse(query: string): Promise<string | null> {
    const { embedding: queryEmbedding } = await embed({
      model: this.embeddingModel,
      value: query,
    });

    const keys = await this.redis.keys('ai:cache:*');
    for (const key of keys) {
      const raw = await this.redis.get(key);
      if (!raw) continue;

      const cached = JSON.parse(raw) as {
        embedding: number[];
        response: string;
        query: string;
      };

      const similarity = this.cosineSimilarity(queryEmbedding, cached.embedding);
      if (similarity > CACHE_THRESHOLD) {
        this.logger.log(`Cache hit (similarity: ${similarity.toFixed(4)}) for: "${query}"`);
        return cached.response;
      }
    }

    return null;
  }

  async cacheResponse(query: string, response: string): Promise<void> {
    const { embedding } = await embed({
      model: this.embeddingModel,
      value: query,
    });

    const hash = createHash('md5').update(query).digest('hex');
    const cacheKey = `ai:cache:${hash}`;

    await this.redis.set(
      cacheKey,
      JSON.stringify({ embedding, response, query }),
      CACHE_TTL_SECONDS,
    );
  }

  async invalidateCache(): Promise<void> {
    const keys = await this.redis.keys('ai:cache:*');
    if (keys.length > 0) {
      await this.redis.del(...keys);
    }
    this.logger.log(`Invalidated ${keys.length} cached responses`);
  }
}
```

```typescript
// WRONG ❌ — Exact-match cache only
async getCached(query: string): Promise<string | null> {
  return this.redis.get(`cache:${query}`); // NO! Misses semantically identical queries
  // "What is our refund policy?" vs "Tell me about refunds" = different keys, same answer
}
```

---

## 16. Agentic RAG — Dynamic Retrieval with Query Decomposition

```typescript
// CORRECT ✅ — Agent dynamically decides retrieval strategy
// src/modules/ai/rag/agentic-retriever.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { generateText, tool } from 'ai';
import { z } from 'zod';
import { AiGatewayService } from '../ai-gateway.service';
import { RetrieverService } from './retriever.service';

@Injectable()
export class AgenticRetrieverService {
  private readonly logger = new Logger(AgenticRetrieverService.name);

  constructor(
    private readonly aiGateway: AiGatewayService,
    private readonly retriever: RetrieverService,
  ) {}

  async retrieve(query: string): Promise<string> {
    const model = this.aiGateway.getModel('smart');

    const result = await generateText({
      model,
      system: `You are a retrieval agent. Given a user query:
1. Decide which knowledge base(s) to search
2. If the query is complex, decompose into sub-queries
3. If retrieved context is insufficient, try broader search terms
4. Synthesize all retrieved information into a final answer`,
      prompt: query,
      tools: {
        searchVectorDb: tool({
          description: 'Search the vector knowledge base for relevant documents',
          parameters: z.object({
            query: z.string().describe('Search query'),
            collection: z.string().default('documents').describe('Collection name'),
            topK: z.number().default(5).describe('Number of results'),
          }),
          execute: async ({ query: q, collection, topK }) => {
            const results = await this.retriever.retrieve(q, collection, topK);
            return results.map((r) => r.text).join('\n---\n');
          },
        }),
        decomposeQuery: tool({
          description: 'Break a complex query into simpler sub-queries',
          parameters: z.object({
            query: z.string().describe('Complex query to decompose'),
          }),
          execute: async ({ query: q }) => {
            const { text } = await generateText({
              model: this.aiGateway.getModel('fast'),
              prompt: `Break this question into 2-4 simpler sub-questions:\n${q}\n\nReturn as JSON array of strings.`,
            });
            return text;
          },
        }),
        searchWeb: tool({
          description: 'Search the web when local knowledge base is insufficient',
          parameters: z.object({
            query: z.string().describe('Web search query'),
          }),
          execute: async ({ query: q }) => {
            this.logger.log(`Web search fallback for: ${q}`);
            return `Web search results for: ${q}`;
          },
        }),
      },
      maxSteps: 5,
    });

    return result.text;
  }
}
```

```typescript
// WRONG ❌ — Single-shot naive retrieval
async retrieve(query: string) {
  const results = await this.qdrant.search('docs', { vector: embedding, limit: 5 });
  return results; // NO! No decomposition, no fallback, no multi-step reasoning
}
```

---

## 17. Re-ranking — Post-Retrieval Re-ranking

```typescript
// CORRECT ✅ — Re-rank after initial vector retrieval
// src/modules/ai/rag/reranker.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface RankedResult {
  text: string;
  score: number;
  originalIndex: number;
}

@Injectable()
export class RerankerService {
  private readonly logger = new Logger(RerankerService.name);
  private readonly cohereApiKey: string;

  constructor(private readonly config: ConfigService) {
    this.cohereApiKey = config.getOrThrow('COHERE_API_KEY');
  }

  async rerank(
    query: string,
    documents: string[],
    topN: number = 5,
  ): Promise<RankedResult[]> {
    const response = await fetch('https://api.cohere.ai/v1/rerank', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cohereApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        query,
        documents,
        top_n: topN,
        model: 'rerank-v3.5',
      }),
    });

    if (!response.ok) {
      this.logger.error(`Rerank API error: ${response.status}`);
      throw new Error('Rerank API failed');
    }

    const data = (await response.json()) as {
      results: Array<{ index: number; relevance_score: number }>;
    };

    return data.results.map((r) => ({
      text: documents[r.index],
      score: r.relevance_score,
      originalIndex: r.index,
    }));
  }
}
```

```typescript
// CORRECT ✅ — Full pipeline: retrieve(top_k=20) -> rerank(top_n=5) -> generate
// src/modules/ai/rag/rag-pipeline.service.ts
import { Injectable } from '@nestjs/common';
import { RetrieverService } from './retriever.service';
import { RerankerService } from './reranker.service';
import { AiGatewayService } from '../ai-gateway.service';

@Injectable()
export class RagPipelineService {
  constructor(
    private readonly retriever: RetrieverService,
    private readonly reranker: RerankerService,
    private readonly aiGateway: AiGatewayService,
  ) {}

  async answer(query: string): Promise<string> {
    // Step 1: Broad retrieval
    const rawResults = await this.retriever.retrieve(query, 'documents', 20);

    // Step 2: Re-rank for precision
    const reranked = await this.reranker.rerank(
      query,
      rawResults.map((r) => r.text),
      5,
    );

    // Step 3: Generate answer with reranked context
    const context = reranked.map((r) => r.text).join('\n\n---\n\n');
    const { text } = await this.aiGateway.generate(
      `Context:\n${context}\n\nQuestion: ${query}\n\nAnswer based ONLY on the provided context.`,
      { tier: 'smart' },
    );

    return text;
  }
}
```

```typescript
// WRONG ❌ — Using raw vector results without re-ranking
const results = await this.retriever.retrieve(query, 'docs', 5);
const context = results.map((r) => r.text).join('\n');
// NO! Vector similarity != relevance. Re-rank for better precision.
```

---

## 18. AI Evaluation — Jest-Based LLM Testing

```typescript
// CORRECT ✅ — LLM quality tests with Jest and LLM-as-judge
// test/ai/ai-quality.spec.ts
import { Test } from '@nestjs/testing';
import { AiGatewayService } from '../../src/modules/ai/ai-gateway.service';
import { RagPipelineService } from '../../src/modules/ai/rag/rag-pipeline.service';
import { generateObject } from 'ai';
import { z } from 'zod';

const EvalResultSchema = z.object({
  relevancy: z.number().min(0).max(1),
  faithfulness: z.number().min(0).max(1),
  completeness: z.number().min(0).max(1),
  reasoning: z.string(),
});

describe('AI Quality Evaluation', () => {
  let aiGateway: AiGatewayService;
  let ragPipeline: RagPipelineService;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      providers: [AiGatewayService, RagPipelineService /* ...dependencies */],
    }).compile();

    aiGateway = module.get(AiGatewayService);
    ragPipeline = module.get(RagPipelineService);
  });

  it('should produce relevant answers for refund policy questions', async () => {
    const question = 'What is the refund policy?';
    const expectedContext = 'Refunds are available within 30 days of purchase.';
    const answer = await ragPipeline.answer(question);

    // Use LLM-as-judge for evaluation
    const { object: evaluation } = await generateObject({
      model: aiGateway.getModel('fast'),
      schema: EvalResultSchema,
      prompt: `Evaluate this AI response:
Question: ${question}
Expected context: ${expectedContext}
AI Answer: ${answer}

Rate relevancy, faithfulness to context, and completeness (0-1 each).`,
    });

    expect(evaluation.relevancy).toBeGreaterThan(0.7);
    expect(evaluation.faithfulness).toBeGreaterThan(0.8);
    expect(evaluation.completeness).toBeGreaterThan(0.6);
  }, 30000);

  it('should not hallucinate beyond provided context', async () => {
    const question = 'What features does the Enterprise plan include?';
    const answer = await ragPipeline.answer(question);

    const { object: evaluation } = await generateObject({
      model: aiGateway.getModel('fast'),
      schema: z.object({
        containsHallucination: z.boolean(),
        hallucinations: z.array(z.string()),
      }),
      prompt: `Check if this answer contains information NOT supported by the knowledge base:
Answer: ${answer}
List any hallucinated claims.`,
    });

    expect(evaluation.containsHallucination).toBe(false);
  }, 30000);
});
```

```typescript
// WRONG ❌ — No AI quality testing
describe('AI', () => {
  it('should return something', async () => {
    const result = await aiService.generate('Hello');
    expect(result).toBeTruthy(); // NO! Tests existence, not quality
  });
});
```

---

## 19. Context Window Management — Token Counting + Auto-Summarization

```typescript
// CORRECT ✅ — Token counting and auto-summarization
// src/modules/ai/context/context-manager.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { AiGatewayService } from '../ai-gateway.service';
import { encoding_for_model, TiktokenModel } from 'tiktoken';

interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

const MAX_CONTEXT_TOKENS = 8000;
const SUMMARY_THRESHOLD = 6000;
const KEEP_RECENT_MESSAGES = 4;

@Injectable()
export class ContextManagerService {
  private readonly logger = new Logger(ContextManagerService.name);

  constructor(private readonly aiGateway: AiGatewayService) {}

  countTokens(text: string, model: TiktokenModel = 'gpt-4o'): number {
    const enc = encoding_for_model(model);
    const tokens = enc.encode(text);
    enc.free();
    return tokens.length;
  }

  countMessagesTokens(messages: ChatMessage[]): number {
    return messages.reduce(
      (total, msg) => total + this.countTokens(msg.content) + 4,
      0,
    );
  }

  async manageContext(messages: ChatMessage[]): Promise<ChatMessage[]> {
    const totalTokens = this.countMessagesTokens(messages);

    if (totalTokens <= SUMMARY_THRESHOLD) {
      return messages;
    }

    this.logger.log(
      `Context exceeds threshold (${totalTokens}/${SUMMARY_THRESHOLD}). Summarizing...`,
    );

    const systemMessage = messages[0];
    const recentMessages = messages.slice(-KEEP_RECENT_MESSAGES);
    const oldMessages = messages.slice(1, -KEEP_RECENT_MESSAGES);

    if (oldMessages.length === 0) {
      return messages;
    }

    const conversationText = oldMessages
      .map((m) => `${m.role}: ${m.content}`)
      .join('\n');

    const { text: summary } = await this.aiGateway.generate(
      `Summarize this conversation concisely, preserving key facts, decisions, and context:\n\n${conversationText}`,
      { tier: 'fast', maxTokens: 500 },
    );

    const managedMessages: ChatMessage[] = [
      systemMessage,
      {
        role: 'system',
        content: `Previous conversation summary:\n${summary}`,
      },
      ...recentMessages,
    ];

    const newTokenCount = this.countMessagesTokens(managedMessages);
    this.logger.log(
      `Context reduced: ${totalTokens} -> ${newTokenCount} tokens`,
    );

    return managedMessages;
  }
}
```

```typescript
// WRONG ❌ — No context management, blindly appending messages
async chat(messages: ChatMessage[]) {
  // Messages grow forever until context window overflow
  return generateText({ model, messages }); // NO! Will crash at 128k+ tokens
}
```

---

## 20. HITL — Human-in-the-Loop Review Queue

```typescript
// CORRECT ✅ — Confidence-based auto-approve or human review
// src/modules/ai/hitl/review.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service';
import { AiGatewayService } from '../ai-gateway.service';
import { ConfigService } from '@nestjs/config';

export interface ReviewItem {
  id: string;
  content: string;
  confidence: number;
  status: 'pending' | 'approved' | 'rejected';
  userId: string;
  reviewerNote?: string;
}

@Injectable()
export class ReviewService {
  private readonly logger = new Logger(ReviewService.name);
  private readonly autoApproveThreshold: number;

  constructor(
    private readonly prisma: PrismaService,
    private readonly aiGateway: AiGatewayService,
    private readonly config: ConfigService,
  ) {
    this.autoApproveThreshold = config.get<number>('AI_AUTO_APPROVE_THRESHOLD', 0.85);
  }

  async generateWithReview(
    prompt: string,
    userId: string,
  ): Promise<{ content: string; status: string; reviewId?: string }> {
    const { text } = await this.aiGateway.generate(prompt, { tier: 'smart' });

    // Estimate confidence via self-evaluation
    const { text: confidenceStr } = await this.aiGateway.generate(
      `Rate your confidence in this answer from 0.0 to 1.0 (number only):\n\nQuestion: ${prompt}\nAnswer: ${text}`,
      { tier: 'fast', maxTokens: 10 },
    );
    const confidence = parseFloat(confidenceStr) || 0.5;

    if (confidence >= this.autoApproveThreshold) {
      this.logger.log(`Auto-approved (confidence: ${confidence})`);
      return { content: text, status: 'auto_approved' };
    }

    // Queue for human review
    const reviewItem = await this.prisma.aiReview.create({
      data: {
        content: text,
        prompt,
        confidence,
        status: 'pending',
        userId,
      },
    });

    this.logger.log(`Queued for review (confidence: ${confidence}): ${reviewItem.id}`);
    return { content: text, status: 'pending_review', reviewId: reviewItem.id };
  }

  async approveReview(reviewId: string, reviewerId: string, note?: string) {
    return this.prisma.aiReview.update({
      where: { id: reviewId },
      data: { status: 'approved', reviewerId, reviewerNote: note },
    });
  }

  async rejectReview(reviewId: string, reviewerId: string, note: string) {
    return this.prisma.aiReview.update({
      where: { id: reviewId },
      data: { status: 'rejected', reviewerId, reviewerNote: note },
    });
  }

  async getPendingReviews(page: number = 1, limit: number = 20) {
    return this.prisma.aiReview.findMany({
      where: { status: 'pending' },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
    });
  }
}
```

```typescript
// CORRECT ✅ — HITL controller with permissions
// src/modules/ai/hitl/review.controller.ts
import { Controller, Post, Patch, Get, Param, Body, Query } from '@nestjs/common';
import { ReviewService } from './review.service';
import { RequirePermissions } from '../../../common/decorators/permissions.decorator';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';

// Auth + Permissions handled by global APP_GUARD — no @UseGuards needed
@Controller('api/v1/ai/reviews')
export class ReviewController {
  constructor(private readonly reviewService: ReviewService) {}

  @Post('generate')
  async generateWithReview(
    @Body('prompt') prompt: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.reviewService.generateWithReview(prompt, userId);
  }

  @Get('pending')
  @RequirePermissions('ai:review')
  async getPending(@Query('page') page: number = 1, @Query('limit') limit: number = 20) {
    return this.reviewService.getPendingReviews(page, limit);
  }

  @Patch(':id/approve')
  @RequirePermissions('ai:review')
  async approve(
    @Param('id') id: string,
    @CurrentUser('id') reviewerId: string,
    @Body('note') note?: string,
  ) {
    return this.reviewService.approveReview(id, reviewerId, note);
  }

  @Patch(':id/reject')
  @RequirePermissions('ai:review')
  async reject(
    @Param('id') id: string,
    @CurrentUser('id') reviewerId: string,
    @Body('note') note: string,
  ) {
    return this.reviewService.rejectReview(id, reviewerId, note);
  }
}
```

```typescript
// WRONG ❌ — No human oversight for AI content
@Post('generate')
async generate(@Body() dto: GenerateDto) {
  const result = await this.aiGateway.generate(dto.prompt);
  return { content: result.text, status: 'published' }; // NO! Auto-publish without review
}
```

---

## 21. Voice AI — Whisper STT + TTS Streaming via WebSocket

```typescript
// CORRECT ✅ — Speech-to-text + Text-to-speech service
// src/modules/ai/voice/voice.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import OpenAI from 'openai';

@Injectable()
export class VoiceService {
  private readonly logger = new Logger(VoiceService.name);
  private readonly openaiClient: OpenAI;

  constructor(private readonly config: ConfigService) {
    this.openaiClient = new OpenAI({
      apiKey: config.getOrThrow('OPENAI_API_KEY'),
    });
  }

  async transcribe(audioBuffer: Buffer, mimeType: string = 'audio/webm'): Promise<string> {
    const file = new File([audioBuffer], 'audio.webm', { type: mimeType });

    const transcription = await this.openaiClient.audio.transcriptions.create({
      model: 'whisper-1',
      file,
      language: 'en',
    });

    this.logger.log(
      `Transcribed ${audioBuffer.length} bytes -> "${transcription.text.slice(0, 50)}..."`,
    );
    return transcription.text;
  }

  async *textToSpeech(
    text: string,
    voice: 'alloy' | 'echo' | 'fable' | 'onyx' | 'nova' | 'shimmer' = 'alloy',
  ): AsyncGenerator<Buffer> {
    const response = await this.openaiClient.audio.speech.create({
      model: 'tts-1',
      voice,
      input: text,
      response_format: 'opus',
    });

    const reader = response.body?.getReader();
    if (!reader) throw new Error('No response body');

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      yield Buffer.from(value);
    }
  }
}
```

```typescript
// CORRECT ✅ — WebSocket gateway for real-time voice streaming
// src/modules/ai/voice/voice.gateway.ts
import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { VoiceService } from './voice.service';
import { AiGatewayService } from '../ai-gateway.service';
import { Logger } from '@nestjs/common';

@WebSocketGateway({ namespace: '/voice', cors: { origin: '*' } })
export class VoiceGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(VoiceGateway.name);

  constructor(
    private readonly voiceService: VoiceService,
    private readonly aiGateway: AiGatewayService,
  ) {}

  handleConnection(client: Socket) {
    this.logger.log(`Voice client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Voice client disconnected: ${client.id}`);
  }

  @SubscribeMessage('audio-chunk')
  async handleAudioChunk(
    @ConnectedSocket() client: Socket,
    @MessageBody() audioData: Buffer,
  ) {
    try {
      // Step 1: Transcribe audio
      const transcript = await this.voiceService.transcribe(audioData);
      client.emit('transcript', { text: transcript });

      // Step 2: Generate AI response
      const { text: aiResponse } = await this.aiGateway.generate(transcript, {
        tier: 'fast',
      });
      client.emit('ai-response-text', { text: aiResponse });

      // Step 3: Stream TTS audio back
      for await (const audioChunk of this.voiceService.textToSpeech(aiResponse)) {
        client.emit('tts-chunk', audioChunk);
      }
      client.emit('tts-done');
    } catch (error) {
      this.logger.error(`Voice processing error: ${error.message}`);
      client.emit('error', { message: 'Voice processing failed' });
    }
  }
}
```

```typescript
// WRONG ❌ — Synchronous file-based voice processing
@Post('voice')
@UseInterceptors(FileInterceptor('audio'))
async processVoice(@UploadedFile() file: Express.Multer.File) {
  const transcript = await this.voiceService.transcribe(file.buffer);
  const aiResponse = await this.aiGateway.generate(transcript);
  const audioBuffer = await this.voiceService.generateFullAudio(aiResponse); // NO! Blocks
  return { transcript, aiResponse, audio: audioBuffer.toString('base64') }; // NO! Huge payload
}
```

---

## 22. Batch AI Processing — BullMQ with Progress Tracking

```typescript
// CORRECT ✅ — Bulk AI processing with BullMQ and progress tracking
// src/modules/ai/batch/batch.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { RedisService } from '../../../common/redis/redis.service';

export interface BatchJob {
  documentIds: string[];
  userId: string;
  operation: 'embed' | 'summarize' | 'classify';
}

export interface BatchProgress {
  jobId: string;
  completed: number;
  total: number;
  percent: number;
  status: 'processing' | 'completed' | 'failed';
  errors: string[];
}

@Injectable()
export class BatchService {
  private readonly logger = new Logger(BatchService.name);

  constructor(
    @InjectQueue('ai-batch') private readonly batchQueue: Queue,
    private readonly redis: RedisService,
  ) {}

  async startBatchJob(job: BatchJob): Promise<{ jobId: string }> {
    const queuedJob = await this.batchQueue.add('process-batch', job, {
      attempts: 1,
      removeOnComplete: { age: 3600, count: 100 },
      removeOnFail: { age: 86400 },
    });

    await this.redis.set(
      `batch:${queuedJob.id}:progress`,
      JSON.stringify({
        jobId: queuedJob.id,
        completed: 0,
        total: job.documentIds.length,
        percent: 0,
        status: 'processing',
        errors: [],
      }),
      3600,
    );

    return { jobId: queuedJob.id! };
  }

  async getProgress(jobId: string): Promise<BatchProgress | null> {
    const raw = await this.redis.get(`batch:${jobId}:progress`);
    return raw ? JSON.parse(raw) : null;
  }
}
```

```typescript
// CORRECT ✅ — BullMQ processor with per-item progress updates
// src/modules/ai/batch/batch.processor.ts
import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Logger } from '@nestjs/common';
import { RetrieverService } from '../rag/retriever.service';
import { RedisService } from '../../../common/redis/redis.service';
import { PrismaService } from '../../../prisma/prisma.service';
import { BatchJob, BatchProgress } from './batch.service';

@Processor('ai-batch', { concurrency: 3 })
export class BatchProcessor extends WorkerHost {
  private readonly logger = new Logger(BatchProcessor.name);

  constructor(
    private readonly retriever: RetrieverService,
    private readonly redis: RedisService,
    private readonly prisma: PrismaService,
  ) {
    super();
  }

  async process(job: Job<BatchJob>): Promise<{ processed: number; errors: string[] }> {
    const { documentIds, userId, operation } = job.data;
    const total = documentIds.length;
    const errors: string[] = [];

    this.logger.log(`Starting batch ${operation} for ${total} documents (user: ${userId})`);

    for (let i = 0; i < documentIds.length; i++) {
      try {
        const doc = await this.prisma.document.findUnique({
          where: { id: documentIds[i] },
        });

        if (!doc) {
          errors.push(`Document ${documentIds[i]} not found`);
          continue;
        }

        switch (operation) {
          case 'embed':
            await this.retriever.upsertDocument('documents', doc.id, doc.content, {
              userId,
              title: doc.title,
            });
            break;
          case 'summarize':
            // Summarize logic here
            break;
          case 'classify':
            // Classify logic here
            break;
        }
      } catch (error) {
        errors.push(`Document ${documentIds[i]}: ${error.message}`);
        this.logger.error(`Batch item error: ${error.message}`);
      }

      // Update progress in Redis
      const progress: BatchProgress = {
        jobId: job.id!,
        completed: i + 1,
        total,
        percent: Math.round(((i + 1) / total) * 100),
        status: i + 1 === total ? 'completed' : 'processing',
        errors,
      };
      await this.redis.set(
        `batch:${job.id}:progress`,
        JSON.stringify(progress),
        3600,
      );
    }

    return { processed: total - errors.length, errors };
  }
}
```

```typescript
// CORRECT ✅ — Controller for batch operations with progress polling
// src/modules/ai/batch/batch.controller.ts
import { Controller, Post, Get, Body, Param, NotFoundException } from '@nestjs/common';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { BatchService } from './batch.service';
import { BatchEmbedDto } from './dto/batch-embed.dto';

// Auth handled by global APP_GUARD — no @UseGuards needed
@Controller('api/v1/ai/batch')
export class BatchController {
  constructor(private readonly batchService: BatchService) {}

  @Post('embed')
  async startBatchEmbed(
    @Body() dto: BatchEmbedDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.batchService.startBatchJob({
      documentIds: dto.documentIds,
      userId,
      operation: 'embed',
    });
  }

  @Get('progress/:jobId')
  async getProgress(@Param('jobId') jobId: string) {
    const progress = await this.batchService.getProgress(jobId);
    if (!progress) throw new NotFoundException('Batch job not found');
    return progress;
  }
}
```

```typescript
// WRONG ❌ — Processing all documents synchronously in API handler
@Post('embed-all')
async embedAll(@Body() dto: BatchEmbedDto) {
  for (const docId of dto.documentIds) { // NO! Blocks API for minutes/hours
    await this.retriever.upsertDocument('docs', docId, doc.content);
  }
  return { status: 'done' }; // NO! Request timeout, no progress tracking
}
```

---

## 23. Error Handling — Custom Exception Filters

```typescript
// CORRECT ✅ — Custom exception classes
// src/common/exceptions/app.exceptions.ts
import { HttpException, HttpStatus } from '@nestjs/common';

export class AppException extends HttpException {
  constructor(
    message: string,
    statusCode: HttpStatus = HttpStatus.INTERNAL_SERVER_ERROR,
    public readonly errorCode?: string,
  ) {
    super(
      {
        statusCode,
        error: errorCode ?? HttpStatus[statusCode],
        message,
        timestamp: new Date().toISOString(),
      },
      statusCode,
    );
  }
}

export class NotFoundException extends AppException {
  constructor(message: string = 'Resource not found') {
    super(message, HttpStatus.NOT_FOUND, 'NOT_FOUND');
  }
}

export class UnauthorizedException extends AppException {
  constructor(message: string = 'Unauthorized') {
    super(message, HttpStatus.UNAUTHORIZED, 'UNAUTHORIZED');
  }
}

export class ForbiddenException extends AppException {
  constructor(message: string = 'Forbidden') {
    super(message, HttpStatus.FORBIDDEN, 'FORBIDDEN');
  }
}

export class ConflictException extends AppException {
  constructor(message: string = 'Resource already exists') {
    super(message, HttpStatus.CONFLICT, 'CONFLICT');
  }
}

export class ValidationException extends AppException {
  constructor(
    message: string = 'Validation failed',
    public readonly errors?: Record<string, string[]>,
  ) {
    super(message, HttpStatus.UNPROCESSABLE_ENTITY, 'VALIDATION_ERROR');
  }
}

export class InsufficientPointsException extends AppException {
  constructor(required: number, balance: number) {
    super(
      `Insufficient points: need ${required}, have ${balance}`,
      HttpStatus.PAYMENT_REQUIRED,
      'INSUFFICIENT_POINTS',
    );
  }
}
```

```typescript
// CORRECT ✅ — Global exception filter
// src/common/filters/all-exceptions.filter.ts
import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let errorCode = 'INTERNAL_ERROR';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();
      if (typeof exceptionResponse === 'object') {
        message = (exceptionResponse as any).message ?? exception.message;
        errorCode = (exceptionResponse as any).error ?? errorCode;
      } else {
        message = exceptionResponse as string;
      }
    } else if (exception instanceof Error) {
      message = exception.message;
      this.logger.error(
        `Unhandled exception: ${exception.message}`,
        exception.stack,
      );
    }

    const errorResponse = {
      statusCode: status,
      error: errorCode,
      message,
      path: request.url,
      timestamp: new Date().toISOString(),
    };

    // Do NOT leak stack traces in production
    if (process.env.NODE_ENV === 'development' && exception instanceof Error) {
      (errorResponse as any).stack = exception.stack;
    }

    response.status(status).json(errorResponse);
  }
}
```

```typescript
// CORRECT ✅ — Application bootstrap with global pipes, filters, and cookies
// src/main.ts
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import * as cookieParser from 'cookie-parser';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    rawBody: true, // Needed for webhook signature verification
  });

  app.setGlobalPrefix('api');

  app.use(cookieParser());

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,            // Strip unknown properties
      forbidNonWhitelisted: true, // Throw on unknown properties
      transform: true,            // Auto-transform payloads to DTO instances
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  app.useGlobalFilters(new AllExceptionsFilter());

  app.enableCors({
    origin: process.env.FRONTEND_URL,
    credentials: true,
  });

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
```

```typescript
// CORRECT ✅ — Prisma service with graceful lifecycle hooks
// src/prisma/prisma.service.ts
import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

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

```typescript
// CORRECT ✅ — Redis service wrapper with clean shutdown
// src/common/redis/redis.service.ts
import { Injectable, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private readonly client: Redis;

  constructor(private readonly config: ConfigService) {
    this.client = new Redis({
      host: config.get('REDIS_HOST', 'localhost'),
      port: config.get<number>('REDIS_PORT', 6379),
      password: config.get('REDIS_PASSWORD'),
      db: config.get<number>('REDIS_DB', 0),
    });
  }

  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (ttlSeconds) {
      await this.client.set(key, value, 'EX', ttlSeconds);
    } else {
      await this.client.set(key, value);
    }
  }

  async del(...keys: string[]): Promise<void> {
    await this.client.del(...keys);
  }

  async keys(pattern: string): Promise<string[]> {
    return this.client.keys(pattern);
  }

  async onModuleDestroy() {
    await this.client.quit();
    this.logger.log('Redis disconnected');
  }
}
```

```typescript
// WRONG ❌ — Generic error handling, leaking internals
@Get(':id')
async getUser(@Param('id') id: string) {
  try {
    return await this.prisma.user.findUnique({ where: { id } });
  } catch (error) {
    throw new HttpException(error.message, 500); // NO! Leaks Prisma error internals
  }
}

// WRONG ❌ — Swallowing errors silently
@Post('register')
async register(@Body() body: any) { // NO! Untyped body
  try {
    return await this.userService.register(body);
  } catch {
    return { success: false }; // NO! Swallows error, no info for debugging
  }
}
```

---

## Dockerfile — Production Build

```dockerfile
# CORRECT ✅ — Multi-stage build with node:22-alpine
FROM node:22-alpine AS builder

WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN npx prisma generate
RUN pnpm build

FROM node:22-alpine AS runner

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nestjs -u 1001

WORKDIR /app
COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /app/package.json ./
COPY --from=builder --chown=nestjs:nodejs /app/prisma ./prisma

USER nestjs
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

```dockerfile
# WRONG ❌ — Single stage, dev dependencies in production
FROM node:22
WORKDIR /app
COPY . .
RUN npm install         # NO! Includes devDependencies
CMD ["npm", "run", "start:dev"]  # NO! Dev mode in production
```

---

## Module Structure — Summary

```
src/
├── main.ts                              # Bootstrap, global pipes/filters
├── app.module.ts                        # Root module
├── prisma/
│   ├── prisma.module.ts
│   └── prisma.service.ts
├── common/
│   ├── auth/
│   │   └── strategies/
│   │       ├── jwt.strategy.ts          # Cookie-based JWT extraction
│   │       └── google.strategy.ts       # Google OAuth2
│   ├── guards/
│   │   ├── jwt-auth.guard.ts            # JWT + blacklist check
│   │   ├── permissions.guard.ts         # RBAC permissions
│   │   └── points.guard.ts             # Credit points billing
│   ├── decorators/
│   │   ├── current-user.decorator.ts
│   │   ├── permissions.decorator.ts
│   │   └── points.decorator.ts
│   ├── filters/
│   │   └── all-exceptions.filter.ts
│   ├── exceptions/
│   │   └── app.exceptions.ts
│   └── redis/
│       ├── redis.module.ts
│       └── redis.service.ts
├── modules/
│   ├── auth/
│   │   ├── auth.module.ts
│   │   ├── auth.controller.ts
│   │   └── auth.service.ts
│   ├── user/
│   │   ├── user.module.ts
│   │   ├── user.controller.ts
│   │   ├── user.service.ts
│   │   ├── user.repository.ts
│   │   └── dto/
│   │       ├── create-user.dto.ts
│   │       └── user-response.dto.ts
│   ├── email/
│   │   ├── email.module.ts
│   │   ├── email.service.ts
│   │   ├── email.processor.ts
│   │   └── templates/
│   │       ├── welcome.hbs
│   │       └── verify-otp.hbs
│   ├── storage/
│   │   ├── storage.module.ts
│   │   ├── storage.controller.ts
│   │   └── storage.service.ts
│   ├── webhook/
│   │   ├── webhook.module.ts
│   │   ├── webhook.controller.ts
│   │   └── webhook.service.ts
│   ├── point/
│   │   ├── point.module.ts
│   │   └── point.service.ts
│   ├── ai/
│   │   ├── ai.module.ts
│   │   ├── ai.controller.ts
│   │   ├── ai-gateway.service.ts
│   │   ├── rag/
│   │   │   ├── retriever.service.ts
│   │   │   ├── reranker.service.ts
│   │   │   ├── rag-pipeline.service.ts
│   │   │   └── agentic-retriever.service.ts
│   │   ├── structured/
│   │   │   └── extractor.service.ts
│   │   ├── cache/
│   │   │   └── semantic-cache.service.ts
│   │   ├── context/
│   │   │   └── context-manager.service.ts
│   │   ├── hitl/
│   │   │   ├── review.service.ts
│   │   │   └── review.controller.ts
│   │   ├── voice/
│   │   │   ├── voice.service.ts
│   │   │   └── voice.gateway.ts
│   │   └── batch/
│   │       ├── batch.service.ts
│   │       ├── batch.processor.ts
│   │       └── batch.controller.ts
│   ├── mcp/
│   │   └── mcp-server.ts
│   └── a2a/
│       └── a2a.controller.ts
└── config/
    └── configuration.ts
```
