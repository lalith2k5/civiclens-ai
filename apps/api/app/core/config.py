from pydantic_settings import BaseSettings
class Settings(BaseSettings):
    PROJECT_NAME: str = "CIVICLENS AI"
    DATABASE_URL: str = "postgresql+psycopg2://localhost:5432/civiclens"
    SECRET_KEY: str = "super-secret-dev-key-change-in-prod"
    class Config:
        env_file = ".env"
settings = Settings()
