import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): string {
    return 'Hello World!';
    //ANCHOR - Where the hello world txt comes from
  }
}
