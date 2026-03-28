import { IsString, IsNotEmpty, IsOptional, IsUUID } from 'class-validator';

export class UploadDocumentDto {
  @IsString() @IsNotEmpty() title!: string;
  @IsString() @IsOptional() moduleName?: string;
  @IsUUID() @IsOptional() entityId?: string;
}
