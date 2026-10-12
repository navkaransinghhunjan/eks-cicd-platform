"""Minimal FastAPI service used as the deployment target."""
import os
import socket

from fastapi import FastAPI

APP_VERSION = os.getenv("APP_VERSION", "dev")

app = FastAPI(title="eks-demo", version=APP_VERSION)


@app.get("/")
def root() -> dict:
    return {"service": "eks-demo", "version": APP_VERSION, "pod": socket.gethostname()}


@app.get("/healthz")
def healthz() -> dict:
    """Liveness: the process is up."""
    return {"status": "ok"}


@app.get("/readyz")
def readyz() -> dict:
    """Readiness: the pod can take traffic."""
    return {"status": "ready"}
