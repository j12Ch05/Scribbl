import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../generated/prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy{
    constructor(config: ConfigService){
        const adapter = new PrismaPg(
            {
                connectionString: config.getOrThrow<string>('DATABASE_URL'),
                //~ getOrThrow() makes it so if DATABASE_URL is null teh connection is thrown
                max: Number(config.get('DB_POOL_MAX') ?? 5),
                //~ by prisma default the DB_POOL_MAX= 10
            }
        );
        super({ adapter });
    }

    async onModuleInit() {   
        // console.log(await this.$queryRaw`select count(*)::int as tags from tags`);
        //^ make sure the DB is composed up when you change it from a comment
        await this.$connect();
    }

    async onModuleDestroy() {
        await this.$disconnect();
    }
}