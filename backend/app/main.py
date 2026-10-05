"""CareMate 後端入口。

啟動：uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
API 文件：http://localhost:8000/docs
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from .firebase import init_firebase
from .routers import audio, chat, health

logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_firebase()      # 啟動時連 Firebase
    yield


app = FastAPI(title="CareMate API", version="0.1.0", lifespan=lifespan)
app.include_router(health.router)
app.include_router(audio.router)
app.include_router(chat.router)
