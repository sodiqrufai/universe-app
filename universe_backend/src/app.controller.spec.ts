import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { SupabaseService } from './supabase/supabase.service';

describe('AppController', () => {
  let controller: AppController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [AppService, { provide: SupabaseService, useValue: {} }],
    }).compile();
    controller = app.get(AppController);
  });

  it('root reports the service name', () => {
    expect(controller.getHello()).toEqual({ service: 'UniVerse API', status: 'ok' });
  });

  it('/health is a cheap liveness probe that never touches the database', () => {
    const res = controller.health();
    expect(res.status).toBe('ok');
    expect(new Date(res.time).getTime()).not.toBeNaN();
  });
});
