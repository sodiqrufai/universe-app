import { Controller, Get, Param, NotFoundException } from '@nestjs/common';
import { readFileSync } from 'fs';
import { join } from 'path';

// Served as plain files, not database rows, so legal text can be edited and
// redeployed without touching app code, and so a moderator with admin panel
// access can never accidentally corrupt Terms & Conditions through a UI meant
// for content moderation. Real edits happen by updating the .md files in
// universe_backend/legal-docs/ and redeploying the backend.
const ALLOWED_DOCS = ['terms', 'privacy'];

@Controller('legal')
export class LegalController {
  @Get(':doc')
  getLegalDoc(@Param('doc') doc: string) {
    if (!ALLOWED_DOCS.includes(doc)) {
      throw new NotFoundException('Unknown legal document');
    }

    const filePath = join(process.cwd(), 'legal-docs', `${doc}.md`);
    try {
      const content = readFileSync(filePath, 'utf-8');
      return { success: true, doc, content };
    } catch (e) {
      throw new NotFoundException('Legal document file not found on server');
    }
  }
}
