import {
  Controller,
  Post,
  Get,
  Body,
  Res,
  Req,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { Response, Request } from 'express';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SessionGuard } from '../../common/guards/session.guard';
import { ConfigService } from '@nestjs/config';
import { ApiResponseDto } from '../../common/dto/api-response.dto';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(
    private authService: AuthService,
    private configService: ConfigService,
  ) {}

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Standard Login', description: 'Authenticate users via email and password. Sets the crm_session HttpOnly cookie.' })
  @ApiResponse({ status: 200, description: 'Login successful', type: ApiResponseDto })
  @ApiResponse({ status: 401, description: 'Invalid credentials' })
  async login(
    @Body() dto: LoginDto,
    @Res({ passthrough: true }) res: Response,
  ) {
    const result = await this.authService.login(dto);
    
    if (result.statusCode === 200 && result.data.token) {
      res.cookie('crm_session', result.data.token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        maxAge: this.configService.get<number>('SESSION_MAX_AGE_MS', 604800000),
      });
    }
    
    return result;
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @UseGuards(SessionGuard)
  @ApiOperation({ summary: 'Logout', description: 'Invalidates the session and clears the cookie.' })
  @ApiResponse({ status: 200, description: 'Logout successful' })
  async logout(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const token = req.cookies['crm_session'];
    const result = await this.authService.logout(token);
    res.clearCookie('crm_session');
    return result;
  }

  @Get('profile')
  @UseGuards(SessionGuard)
  @ApiOperation({ summary: 'Get current profile', description: 'Returns details and permissions for the logged-in user.' })
  @ApiResponse({ status: 200, description: 'Profile retrieved', type: ApiResponseDto })
  async getProfile(@CurrentUser() user: any) {
    return this.authService.getProfile(user.id);
  }

  @Public()
  @Post('forgot-password')
  @ApiOperation({ summary: 'Initiate password reset' })
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.authService.forgotPassword(dto);
  }

  @Public()
  @Post('reset-password')
  @ApiOperation({ summary: 'Complete password reset' })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(dto);
  }

  @Get('session')
  @UseGuards(SessionGuard)
  @ApiOperation({ summary: 'Validate session', description: 'Checking if the session cookie is still valid.' })
  @ApiResponse({ status: 200, description: 'Session is valid', type: ApiResponseDto })
  async getSession(@CurrentUser() user: any) {
    return { rid: 's-session-valid', statusCode: 200, data: user };
  }
}
