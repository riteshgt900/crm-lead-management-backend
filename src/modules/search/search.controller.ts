import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { SearchService } from './search.service';
import { SearchQueryDto } from './dto/search.dto';
import { SessionGuard } from '../../common/guards/session.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ApiResponseDto } from '../../common/dto/api-response.dto';

@ApiTags('Search')
@Controller('search')
@UseGuards(SessionGuard)
export class SearchController {
  constructor(private searchService: SearchService) {}

  @Get()
  @ApiOperation({ summary: 'Global Search', description: 'Search across leads, projects, and contacts using a single query string.' })
  @ApiResponse({ status: 200, description: 'Search results retrieved successfully', type: ApiResponseDto })
  async globalSearch(@Query() dto: SearchQueryDto, @CurrentUser() user: any) {
    return this.searchService.globalSearch(dto, user);
  }
}
