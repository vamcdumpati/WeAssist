"""app/routers/auth.py – /register and /login endpoints"""

import hashlib
# pyrefly: ignore [missing-import]
from fastapi import APIRouter, HTTPException
from postgrest.exceptions import APIError as PostgrestAPIError
# pyrefly: ignore [missing-import]
from app.models.schemas import RegisterRequest, LoginRequest, UserResponse, MessageResponse
# pyrefly: ignore [missing-import]
from app.db.client import supabase

router = APIRouter(prefix="/auth", tags=["Auth"])

# ─────────────────────────────────────────────
# NOTE: Ensure these table names EXACTLY match
# the tables created in your Supabase project.
# ─────────────────────────────────────────────
USERS_TABLE = "users"
CARETAKERS_TABLE = "caretakers"


def _hash_password(password: str) -> str:
    """Simple SHA-256 hash. For production, use bcrypt via passlib."""
    return hashlib.sha256(password.encode()).hexdigest()


def _handle_supabase_error(err: PostgrestAPIError, context: str = "Database operation") -> None:
    """Translate PostgREST errors into meaningful HTTP exceptions."""
    code = getattr(err, "code", "") or ""
    message = getattr(err, "message", str(err)) or str(err)

    # PGRST125 – table / path not found in PostgREST schema cache
    if code == "PGRST125" or "Invalid path" in message:
        raise HTTPException(
            status_code=503,
            detail=(
                f"{context} failed: database table not found. "
                "Please verify the table names in your Supabase project."
            ),
        )
    # 23505 – unique-constraint violation (duplicate row)
    if code == "23505" or "duplicate" in message.lower():
        raise HTTPException(status_code=409, detail="A record with that value already exists.")

    # Generic fallback
    raise HTTPException(status_code=500, detail=f"{context} failed: {message}")


# ─────────────────────────────────────────────────────────────────────
# POST /auth/register
# ─────────────────────────────────────────────────────────────────────
@router.post("/register", response_model=MessageResponse, status_code=201)
async def register(body: RegisterRequest):
    """
    Register a new user.

    Flutter usage:
        POST /auth/register
        {
          "name": "Rahul",
          "email": "rahul@example.com",
          "phone": "9876543210",
          "password": "secret123",
          "role": "admin"
        }
    """
    # 1. Check duplicate email
    try:
        existing = (
            supabase.table(USERS_TABLE)
            .select("id")
            .eq("email", body.email)
            .execute()
        )
    except PostgrestAPIError as e:
        _handle_supabase_error(e, "Email uniqueness check")

    if existing.data:
        raise HTTPException(status_code=409, detail="Email already registered")

    # 2. Insert new user
    row = {
        "name": body.name,
        "email": body.email,
        "phone": body.phone,
        "password_hash": _hash_password(body.password),
        "role": body.role,
    }

    try:
        result = supabase.table(USERS_TABLE).insert(row).execute()
    except PostgrestAPIError as e:
        _handle_supabase_error(e, "User registration")

    if not result.data:
        raise HTTPException(status_code=500, detail="Registration failed: no data returned")

    user = result.data[0]

    # 3. If care taker, also create a caretaker profile
    if body.role == "care taker":
        name_parts = body.name.split(maxsplit=1)
        first_name = name_parts[0]
        last_name = name_parts[1] if len(name_parts) > 1 else ""

        caretaker_row = {
            "id": user["id"],
            "first_name": first_name,
            "last_name": last_name,
            "email": body.email,
            "mobile": body.phone,
        }
        try:
            caretaker_result = supabase.table(CARETAKERS_TABLE).insert(caretaker_row).execute()
        except PostgrestAPIError as e:
            # Roll back user to maintain integrity
            try:
                supabase.table(USERS_TABLE).delete().eq("id", user["id"]).execute()
            except Exception:
                pass
            _handle_supabase_error(e, "Caretaker profile creation")

        if not caretaker_result.data:
            try:
                supabase.table(USERS_TABLE).delete().eq("id", user["id"]).execute()
            except Exception:
                pass
            raise HTTPException(status_code=500, detail="Failed to create caretaker profile record")

    return MessageResponse(
        message="Registration successful",
        data={
            "user_id": user["id"],
            "name": user["name"],
            "email": user["email"],
            "phone": user["phone"],
            "role": user["role"],
        },
    )


# ─────────────────────────────────────────────────────────────────────
# POST /auth/login
# ─────────────────────────────────────────────────────────────────────
@router.post("/login", response_model=MessageResponse)
async def login(body: LoginRequest):
    """
    Login and get user_id.
    (In production, return a JWT instead.)
    """
    try:
        result = (
            supabase.table(USERS_TABLE)
            .select("*")
            .eq("email", body.email)
            .execute()
        )
    except PostgrestAPIError as e:
        _handle_supabase_error(e, "Login lookup")

    if not result.data:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    user = result.data[0]

    if user["password_hash"] != _hash_password(body.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Enforce role-based access: only super admin or admin can log in from the web app
    if user.get("role") not in ["super admin", "admin"]:
        raise HTTPException(
            status_code=403,
            detail="Access denied. Care takers cannot login from the web app.",
        )

    return MessageResponse(
        message="Login successful",
        data={
            "user_id": user["id"],
            "name": user["name"],
            "email": user["email"],
            "phone": user["phone"],
            "role": user.get("role", "care taker"),
        },
    )


# ─────────────────────────────────────────────────────────────────────
# GET /auth/user/{user_id}
# ─────────────────────────────────────────────────────────────────────
@router.get("/user/{user_id}", response_model=UserResponse)
async def get_user(user_id: str):
    try:
        result = (
            supabase.table(USERS_TABLE)
            .select("id, name, email, phone, role")
            .eq("id", user_id)
            .execute()
        )
    except PostgrestAPIError as e:
        _handle_supabase_error(e, "User fetch")

    if not result.data:
        raise HTTPException(status_code=404, detail="User not found")

    u = result.data[0]
    return UserResponse(
        id=u["id"],
        name=u["name"],
        email=u["email"],
        phone=u["phone"],
        role=u.get("role", "care taker"),
    )
