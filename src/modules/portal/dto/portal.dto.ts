import { IsString, IsNotEmpty, IsUUID, IsOptional } from 'class-validator';

export class LoginDto {
  @IsString()
  @IsNotEmpty()
  token!: string;
}

export class AddCommentDto {
  @IsUUID()
  @IsNotEmpty()
  taskId!: string;

  @IsString()
  @IsNotEmpty()
  content!: string;
}

export class UploadDocDto {
  @IsUUID()
  @IsNotEmpty()
  projectId!: string;

  @IsString()
  @IsNotEmpty()
  fileName!: string;

  @IsString()
  @IsOptional()
  fileSize?: string;
}

export class InviteDto {
  @IsUUID()
  @IsNotEmpty()
  projectId!: string;

  @IsString()
  @IsNotEmpty()
  email!: string;

  @IsOptional()
  @IsString()
  role?: string;
}
