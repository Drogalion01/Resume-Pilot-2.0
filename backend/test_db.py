import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

engine = create_async_engine('postgresql+asyncpg://neondb_owner:npg_iZTFob9YM0KJ@ep-hidden-moon-aovlgq2g-pooler.c-2.ap-southeast-1.aws.neon.tech/neondb')

async def main():
    async with engine.connect() as conn:
        res = await conn.execute(text("SELECT table_name FROM information_schema.tables WHERE table_schema='public'"))
        print([r[0] for r in res])

asyncio.run(main())
