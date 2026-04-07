import sys
from pathlib import Path

# Add the 'backend' folder to Python path so that 'app.foo' imports work!
sys.path.append(str(Path(__file__).parent / "backend"))

from app.main import app

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=10000)
