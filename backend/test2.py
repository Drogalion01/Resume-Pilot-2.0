import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

engine = create_async_engine('postgresql+asyncpg://neondb_owner:npg_iZTFob9YM0KJ@ep-hidden-moon-aovlgq2g-pooler.c-2.ap-southeast-1.aws.neon.tech/neondb?ssl=require')

async def main():
    async with engine.connect() as conn:
        await conn.execute(text('SELECT 1'))
        print('SUCCESS')

asyncio.run(main())
