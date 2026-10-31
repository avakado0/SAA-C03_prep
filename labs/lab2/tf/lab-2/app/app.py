from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def home():
    return {
        "message": "Hello from Lab 2 EC2!",
        "lab": "AWS SAA Lab 2",
        "status": "public",
    }
