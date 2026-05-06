import { Controller, Get, Post, Body, Param, UseGuards, Req, Res, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiCookieAuth, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { PortalService } from './portal.service';
import { PortalSessionGuard } from './guards/portal-session.guard';
import { CurrentPortalUser } from './decorators/current-portal-user.decorator';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { LoginDto, AddCommentDto, UploadDocDto, InviteDto } from './dto/portal.dto';
import { Response } from 'express';

@ApiTags('Portal')
@Controller('portal')
export class PortalController {
  constructor(private readonly portalService: PortalService) {}

  @Post('login')
  @ApiOperation({ summary: 'Login to portal' })
  @ApiResponse({ status: 200, description: 'Successful login' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async login(@Body() dto: LoginDto, @Res({ passthrough: true }) res: Response) {
    const result = await this.portalService.login(dto);
    if (result && result.session_token) {
      res.cookie('crm_portal_session', result.session_token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        maxAge: 7 * 24 * 60 * 60 * 1000, 
      });
    }
    return result;
  }

  @UseGuards(PortalSessionGuard)
  @Get('projects')
  @ApiCookieAuth('crm_portal_session')
  @ApiOperation({ summary: 'Get portal projects' })
  @ApiResponse({ status: 200, description: 'List of projects for the portal user' })
  async getProjects(@CurrentPortalUser() portalUser: any) {
    return this.portalService.getProjects(portalUser.token);
  }

  @UseGuards(PortalSessionGuard)
  @Get('projects/:id')
  @ApiCookieAuth('crm_portal_session')
  @ApiOperation({ summary: 'Get portal project details' })
  @ApiParam({ name: 'id', description: 'Project ID', type: 'string' })
  @ApiResponse({ status: 200, description: 'Project details returned successfully' })
  async getProjectDetails(@CurrentPortalUser() portalUser: any, @Param('id') id: string) {
    return this.portalService.getProjectDetails(portalUser.token, id);
  }

  @UseGuards(PortalSessionGuard)
  @Post('comments')
  @ApiCookieAuth('crm_portal_session')
  @ApiOperation({ summary: 'Add a comment via portal' })
  @ApiResponse({ status: 201, description: 'Comment added successfully' })
  async addComment(@CurrentPortalUser() portalUser: any, @Body() dto: AddCommentDto) {
    return this.portalService.addComment(portalUser.token, dto);
  }

  @UseGuards(PortalSessionGuard)
  @Post('upload')
  @ApiCookieAuth('crm_portal_session')
  @ApiOperation({ summary: 'Upload document via portal' })
  @ApiResponse({ status: 201, description: 'Document uploaded successfully' })
  async uploadDocument(@CurrentPortalUser() portalUser: any, @Body() dto: UploadDocDto) {
    return this.portalService.uploadDocument(portalUser.token, dto);
  }

  // Internal Administrative route - Uses standard SessionGuard
  @UseGuards(SessionGuard)
  @Post('admin/invite')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Send portal invite to a user (Admin/Internal only)' })
  @ApiResponse({ status: 200, description: 'Invite sent successfully' })
  async inviteToPortal(@CurrentUser() user: any, @Body() dto: InviteDto) {
    return this.portalService.invite(user.id, dto);
  }
}
