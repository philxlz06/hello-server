from fastapi import FastAPI

app= FastAPI()

@app.get("/")
def root():
    return {"messsage": "hello from philip's server"}

@app.get("/health")
def health():
    return {"status": "ok"}
