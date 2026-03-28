import { IsString, IsNotEmpty, IsOptional, IsEnum, IsUUID } from 'class-validator';

export class CreateCommunicationDto {
  @IsEnum(['call', 'email', 'meeting', 'whatsapp', 'slack', 'other']) type!: string;
  @IsString() @IsNotEmpty() subject!: string;
  @IsString() @IsOptional() content?: string;
  @IsUUID() @IsOptional() contactId?: string;
  @IsString() @IsOptional() moduleName?: string;
  @IsUUID() @IsOptional() entityId?: string;
}
