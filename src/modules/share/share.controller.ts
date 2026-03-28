import { Controller, Get, Param } from '@nestjs/common';
import { ShareService } from './share.service';
import { Public } from '../../common/decorators/public.decorator';

@Controller('share')
export class ShareController {
  constructor(private shareService: ShareService) {}

  @Public()
  @Get(':token')
  async getSharedEntity(@Param('token') token: string) {
    return this.shareService.getSharedEntity(token);
  }
}
