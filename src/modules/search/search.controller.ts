import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { SearchService } from './search.service';
import { SearchQueryDto } from './dto/search.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('search')
@UseGuards(SessionGuard)
export class SearchController {
  constructor(private searchService: SearchService) {}

  @Get()
  async globalSearch(@Query() dto: SearchQueryDto, @CurrentUser() user: any) {
    return this.searchService.globalSearch(dto, user);
  }
}
