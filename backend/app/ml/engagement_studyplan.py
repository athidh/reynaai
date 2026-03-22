"""Engagement matrix builder + deterministic study-plan generator.

Usage (from shell):
  python engagement_studyplan.py --input data.csv --student_id 12345 --out engagement_matrix.csv

Functions:
  - load_data(path) -> pd.DataFrame
  - build_engagement_matrix(raw_df) -> engagement_df
  - generate_study_plan(engagement_df, student_id) -> dict

Design summary:
  - The code inspects columns and picks common column names for: student id,
    timestamp/date, interaction counts (clicks/events), time_spent, and
    submission/score columns if present.
  - Features computed per student:
    * total_interactions: sum of available interaction-count columns, or row counts.
    * days_active: unique active days.
    * interactions_first_28_days: interactions in the 28-day window after student's first activity.
    * avg_interactions_per_active_day: total_interactions / days_active.
    * recency_days: days since last activity (relative to max date in data).
    * weekly_activity_ratio: avg interactions in last 4 weeks / avg in first 4 weeks (consistency proxy).
    * submissions_count (if submission-like column exists)
    * avg_time_per_session (if time_spent exists)

  - Engagement score: min-max normalized weighted sum of selected features.
    Thresholds: score < 0.33 -> low; 0.33-0.66 -> medium; >=0.66 -> high.
  - Consistency: based on weekly_activity_ratio: <0.8 -> dropping, >1.2 -> increasing, else stable.

  - Study-plan mapping (deterministic): base minutes by engagement level
    (low:90, medium:60, high:30); adjustments for consistency (dropping +30, increasing -10 min, bounded >=20).

All logic is deterministic and transparent in code & docstrings.
"""

from __future__ import annotations
import argparse
from collections import defaultdict
import json
from typing import Dict, Any

import pandas as pd
import numpy as np
from datetime import timedelta
import os


try:
    import openai
except Exception:  # pragma: no cover - optional dependency
    openai = None
try:
    import requests
except Exception:  # pragma: no cover - optional dependency
    requests = None


def load_data(path: str) -> pd.DataFrame:
    """Load CSV (or other pandas-readable) into DataFrame.

    Returns raw DataFrame.
    """
    df = pd.read_csv(path)
    return df


def _guess_columns(df: pd.DataFrame) -> Dict[str, str]:
    """Inspect df and guess useful column names. Returns mapping of roles to column names.

    Roles considered: student_id, timestamp (date), interaction_count, clicks, time_spent, submission, score
    """
    cols = {c.lower(): c for c in df.columns}
    mapping = {}

    # student id
    for cand in ("student_id", "studentid", "id", "id_student", "userid", "user_id"):
        if cand in cols:
            mapping["student_id"] = cols[cand]
            break

    # timestamp/date
    for cand in ("date", "timestamp", "activity_date", "time", "datetime"):
        if cand in cols:
            mapping["timestamp"] = cols[cand]
            break

    # interaction-like counts
    for cand in ("clicks", "num_clicks", "events", "num_events", "interactions", "activity_count"):
        if cand in cols:
            mapping.setdefault("interaction_cols", []).append(cols[cand])

    # time spent
    for cand in ("time_spent", "duration", "seconds", "time_on_task"):
        if cand in cols:
            mapping["time_spent"] = cols[cand]
            break

    # submission/assessment
    for cand in ("submission", "submissions", "num_submissions", "assignment_submitted"):
        if cand in cols:
            mapping["submissions"] = cols[cand]
            break

    # score
    for cand in ("score", "grade", "marks", "assessment_score"):
        if cand in cols:
            mapping["score"] = cols[cand]
            break

    return mapping


def build_engagement_matrix(raw_df: pd.DataFrame) -> pd.DataFrame:
    """Build per-student engagement matrix from raw interaction rows.

    This function inspects columns, computes features, and returns a DataFrame
    indexed by `student_id` with engagement features as columns.

    Returned features (always):
      - total_interactions
      - days_active
      - interactions_first_28_days
      - avg_interactions_per_active_day
      - recency_days
      - weekly_activity_ratio
    Additional features when columns exist:
      - submissions_count
      - avg_time_per_session

    Also ensures no duplicate student_id rows.
    """
    df = raw_df.copy()
    mapping = _guess_columns(df)

    if "student_id" not in mapping:
        raise ValueError("Could not find a student id column. Provide a column named like student_id or id.")

    sid = mapping["student_id"]

    # Ensure a timestamp column exists or create a synthetic one based on row order
    if "timestamp" in mapping:
        tcol = mapping["timestamp"]
        # attempt to parse to datetime
        df[tcol] = pd.to_datetime(df[tcol], errors="coerce")
    else:
        # create a synthetic timestamp grouping per-row (not ideal but fallback)
        df["__synthetic_ts"] = pd.NaT
        tcol = "__synthetic_ts"

    # Interaction count per row: either sum of available interaction-like columns, or 1 per row
    if "interaction_cols" in mapping and mapping["interaction_cols"]:
        interaction_cols = mapping["interaction_cols"]
        df["__row_interactions"] = df[interaction_cols].fillna(0).sum(axis=1)
    else:
        df["__row_interactions"] = 1.0

    # If date exists, extract date-only for day counts
    if tcol in df.columns and pd.api.types.is_datetime64_any_dtype(df[tcol]):
        df["__date"] = df[tcol].dt.date
    else:
        df["__date"] = pd.NaT

    # Prepare per-student aggregations
    grouped = df.groupby(sid)

    total_interactions = grouped["__row_interactions"].sum().rename("total_interactions")
    days_active = grouped["__date"].nunique(dropna=True).rename("days_active")

    # first and last activity dates
    if tcol in df.columns and pd.api.types.is_datetime64_any_dtype(df[tcol]):
        first_activity = grouped[tcol].min()
        last_activity = grouped[tcol].max()
        # recency relative to max date in data
        max_date = df[tcol].max()
        recency_days = (max_date - last_activity).dt.days.rename("recency_days")
    else:
        first_activity = None
        last_activity = None
        recency_days = pd.Series(index=total_interactions.index, data=np.nan, name="recency_days")

    # interactions in first 28 days after first activity (if timestamps available)
    interactions_first_28 = pd.Series(index=total_interactions.index, data=0.0, name="interactions_first_28_days")
    weekly_activity_ratio = pd.Series(index=total_interactions.index, data=1.0, name="weekly_activity_ratio")

    if first_activity is not None:
        # merge first_activity back into df for filtering
        fa = first_activity.rename("__first_act").reset_index()
        df = df.merge(fa, how="left", on=sid)
        df_valid = df[df[tcol].notna()].copy()

        # first 28 days window
        df_valid["__days_since_first"] = (df_valid[tcol] - df_valid["__first_act"]).dt.days
        mask_28 = df_valid["__days_since_first"].between(0, 27)
        first28 = df_valid[mask_28].groupby(sid)["__row_interactions"].sum()
        interactions_first_28 = first28.reindex(total_interactions.index).fillna(0)

        # weekly averages: define week buckets relative to first activity
        df_valid["__week_index"] = (df_valid["__days_since_first"] // 7).astype(int)
        per_week = df_valid.groupby([sid, "__week_index"])["__row_interactions"].sum().reset_index()

        # compute avg of first 4 weeks and last 4 weeks available
        first4 = per_week[per_week["__week_index"].between(0, 3)].groupby(sid)["__row_interactions"].mean()
        last4 = per_week.groupby(sid).apply(
            lambda g: g.sort_values("__week_index").tail(4)["__row_interactions"].mean() if not g.empty else np.nan
        )

        first4 = first4.reindex(total_interactions.index).fillna(0)
        last4 = last4.reindex(total_interactions.index).fillna(0)
        # ratio, avoid divide-by-zero
        weekly_activity_ratio = (last4 / (first4.replace({0: np.nan}))).fillna(1.0)

    # avg interactions per active day
    avg_interactions_per_active_day = (total_interactions / days_active.replace({0: np.nan})).rename("avg_interactions_per_active_day").fillna(0)

    features = pd.concat([
        total_interactions,
        days_active,
        interactions_first_28,
        avg_interactions_per_active_day,
        recency_days,
        weekly_activity_ratio,
    ], axis=1)

    # optional features
    if "submissions" in mapping:
        subcol = mapping["submissions"]
        submissions_count = grouped[subcol].sum().rename("submissions_count")
        features = pd.concat([features, submissions_count], axis=1)

    if "time_spent" in mapping:
        tcolname = mapping["time_spent"]
        # assume time_spent is in seconds or minutes; compute avg per session (row)
        avg_time = grouped[tcolname].mean().rename("avg_time_per_session")
        features = pd.concat([features, avg_time], axis=1)

    # Fill NaNs with zeros where appropriate
    features["total_interactions"] = features["total_interactions"].fillna(0)
    features["days_active"] = features["days_active"].fillna(0).astype(int)
    if "interactions_first_28_days" in features.columns:
        features["interactions_first_28_days"] = features["interactions_first_28_days"].fillna(0)
    else:
        features["interactions_first_28_days"] = 0
    features["avg_interactions_per_active_day"] = features["avg_interactions_per_active_day"].fillna(0)
    if "recency_days" in features.columns:
        features["recency_days"] = features["recency_days"].fillna(np.nan)
    else:
        features["recency_days"] = np.nan
    if "weekly_activity_ratio" in features.columns:
        features["weekly_activity_ratio"] = features["weekly_activity_ratio"].fillna(1.0)
    else:
        features["weekly_activity_ratio"] = 1.0

    # Ensure index named student_id for clarity
    features.index.name = "student_id"

    return features.reset_index()


def _minmax_series(s: pd.Series) -> pd.Series:
    mn = s.min()
    mx = s.max()
    if pd.isna(mn) or pd.isna(mx) or mx == mn:
        return pd.Series(0.5, index=s.index)
    return (s - mn) / (mx - mn)


def _compute_engagement_score(df: pd.DataFrame) -> pd.Series:
    """Compute a deterministic engagement score (0..1) from features.

    Weights are chosen to capture breadth, recency, and consistency.
    """
    # Use available features with fallback constants
    parts = {}
    parts["total"] = _minmax_series(df["total_interactions"]) * 0.4
    parts["days"] = _minmax_series(df["days_active"]) * 0.2
    parts["avg_day"] = _minmax_series(df["avg_interactions_per_active_day"]) * 0.2
    # recency: more recent -> higher score (recency_days small => high). invert minmax
    if "recency_days" in df.columns:
        rec = df["recency_days"].fillna(df["recency_days"].max())
        rec_norm = 1 - _minmax_series(rec)
        parts["recency"] = rec_norm * 0.15
    else:
        parts["recency"] = pd.Series(0.0, index=df.index)

    # consistency: weekly_activity_ratio around 1 is stable (reward stability), large deviations reduce score
    war = df["weekly_activity_ratio"].fillna(1.0)
    # map ratio to stability score: 1 -> 1, extremes -> 0
    stability = 1 - _minmax_series((war - 1).abs())
    parts["stability"] = stability * 0.05

    total_score = sum(parts.values())
    # final clamp
    total_score = total_score.clip(0, 1)
    return total_score


def generate_study_plan(engagement_df: pd.DataFrame, student_id: Any) -> Dict[str, Any]:
    """Generate a deterministic 7-day study plan for the given student_id.

    The plan is based only on the engagement features in `engagement_df`.

    Returns a dictionary JSON-like object with keys: student_id, engagement_profile, daily_minutes, days(list).

    Influence of features on plan (summary):
      - total_interactions & days_active & avg_interactions_per_active_day -> higher means lower required minutes
      - recency_days -> large recency increases recommended review and minutes
      - weekly_activity_ratio -> consistency classification (dropping/increasing/stable)

    Thresholds:
      - engagement_score: <0.33 low, 0.33-0.66 medium, >=0.66 high
      - consistency: weekly_activity_ratio <0.8 -> dropping, >1.2 -> increasing, else stable
    """
    if "student_id" in engagement_df.columns:
        df = engagement_df.set_index("student_id")
    else:
        raise ValueError("engagement_df must contain a 'student_id' column")

    if student_id not in df.index:
        raise KeyError(f"student_id {student_id} not found in engagement_df")

    row = df.loc[student_id]

    # compute engagement score
    score = _compute_engagement_score(df).loc[student_id]

    if score < 0.33:
        level = "low"
    elif score < 0.66:
        level = "medium"
    else:
        level = "high"

    war = float(row.get("weekly_activity_ratio", 1.0))
    if war < 0.8:
        consistency = "dropping"
    elif war > 1.2:
        consistency = "increasing"
    else:
        consistency = "stable"

    # Base minutes by engagement level (deterministic)
    base_minutes = {"low": 90, "medium": 60, "high": 30}[level]

    # adjust for consistency
    if consistency == "dropping":
        adj = 30
    elif consistency == "increasing":
        adj = -10
    else:
        adj = 0

    # further adjust by recency (students with long recency need a little more)
    recency = float(row.get("recency_days", np.nan)) if not pd.isna(row.get("recency_days", np.nan)) else 0
    recency_adj = 0
    if not np.isnan(recency) and recency > 30:
        recency_adj = min(30, int(recency // 30) * 10)

    daily_minutes = max(20, base_minutes + adj + recency_adj)

    # Build a simple 7-day plan pattern depending on level and weak areas
    # Focus types mapping (deterministic by level)
    if level == "low":
        week_pattern = [
            ("Review notes", ["Skim lecture notes", "Make summary sheet"]),
            ("Watch lectures", ["Watch one recorded lecture", "Take notes"]),
            ("Practice problems", ["Solve 2-3 practice problems"]),
            ("Targeted revision", ["Identify weakest topic", "Do focused exercises"]),
            ("Mock test", ["Short timed quiz", "Review mistakes"]),
            ("Reflection", ["Review week progress", "Plan next steps"]),
            ("Mixed practice", ["Mix of problems and review"]),
        ]
    elif level == "medium":
        week_pattern = [
            ("Review notes", ["Revise summaries", "Flashcards for facts"]),
            ("Watch lectures", ["Watch selected lecture clips"]),
            ("Practice problems", ["Solve 4-6 problems"]),
            ("Focused practice", ["Drill on weaker subtopics"]),
            ("Mock test", ["Timed practice test (short)", "Review errors"]),
            ("Active recall", ["Teach a concept aloud"]),
            ("Mixed practice", ["Mixed problems + quick review"]),
        ]
    else:  # high
        week_pattern = [
            ("Warm-up review", ["Quick recap of notes"]),
            ("Apply concepts", ["Solve challenging problems"]),
            ("Practice problems", ["Timed problem set"]),
            ("Deep dive", ["Focus on advanced topics"]),
            ("Mock test", ["Full practice test", "Detailed review"]),
            ("Reflection", ["Analyze mistakes + plan"]),
            ("Consolidation", ["Flashcards + quick drills"]),
        ]

    # If weekly_activity_ratio indicates dropping, add engagement tip
    tip = None
    if level == "low" or consistency == "dropping":
        tip = "Break study into short focused blocks and set a recurring daily reminder."
    elif consistency == "increasing":
        tip = "Keep the momentum: schedule same time daily and track streaks."
    else:
        tip = "Keep consistent: prefer daily short sessions over infrequent long ones."

    days = []
    for i, (focus, tasks) in enumerate(week_pattern, start=1):
        minutes = int(daily_minutes * (1.0 - 0.05 * ((i - 1) // 2)))  # small deterministic taper
        day_entry = {
            "day": i,
            "focus": focus,
            "recommended_minutes": minutes,
            "tasks": tasks,
            "tip": tip if (level == "low" or consistency == "dropping") else None,
        }
        days.append(day_entry)

    profile = {
        "engagement_score": float(score),
        "level": level,
        "consistency": consistency,
        "components": {
            "total_interactions": float(row.get("total_interactions", 0)),
            "days_active": int(row.get("days_active", 0)) if not pd.isna(row.get("days_active", np.nan)) else None,
            "avg_interactions_per_active_day": float(row.get("avg_interactions_per_active_day", 0)),
            "recency_days": None if pd.isna(row.get("recency_days", np.nan)) else float(row.get("recency_days")),
            "weekly_activity_ratio": float(row.get("weekly_activity_ratio", 1.0)),
        },
    }

    plan = {
        "student_id": student_id,
        "engagement_profile": profile,
        "daily_minutes": daily_minutes,
        "days": days,
    }

    return plan


def generate_study_plan_with_llm(engagement_profile: Dict[str, Any], *, student_rows: list | None = None, model: str = "gpt-3.5-turbo", temperature: float = 0.2) -> Dict[str, Any]:
    """Generate a study plan by calling an LLM using the given `engagement_profile`.

    `engagement_profile` should be the `engagement_profile` dict produced by
    `generate_study_plan(...)` (contains features and metadata).

    Requires the `openai` package and an environment variable `OPENAI_API_KEY`.
    Returns a dict parsed from the LLM JSON output.
    """
    if openai is None:
        raise RuntimeError("openai package is not installed. Install via `pip install openai` to use LLM features.")

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY environment variable not set. Export your OpenAI key to use LLM features.")

    openai.api_key = api_key

    system_prompt = (
        "You are an assistant that creates practical 7-day study plans for learners. "
        "Given a concise engagement profile JSON, produce a JSON object with keys: `student_id`, `engagement_profile`, `daily_minutes`, and `days` where `days` is a list of 7 day objects. "
        "Each day object must include `day` (1-7), `focus`, `recommended_minutes` (int), `tasks` (list of short task strings), and optional `tip`. "
        "Do not include any extra explanatory text outside the JSON."
    )

    # Include raw student rows when available to give the LLM richer context
    payload_obj = {"engagement_profile": engagement_profile}
    if student_rows is not None:
        payload_obj["student_rows"] = student_rows

    user_prompt = (
        "Here is the engagement profile (JSON) and optionally recent raw interactions for the target student. "
        "Use these to decide intensity, focus areas, and a concrete 7-day task list. Return only valid JSON matching the schema described in the system prompt.\n\n"
        + json.dumps(payload_obj)
    )

    resp = openai.ChatCompletion.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=temperature,
        max_tokens=800,
    )

    text = resp["choices"][0]["message"]["content"].strip()

    # Sometimes the model returns code fences; strip them if present
    if text.startswith("```"):
        # remove fences
        lines = text.splitlines()
        if lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        text = "\n".join(lines)

    # Parse JSON
    try:
        plan = json.loads(text)
    except Exception as exc:
        raise RuntimeError(f"Failed to parse JSON from LLM response: {exc}\nResponse text:\n{text}")

    return plan


def generate_study_plan_with_nim(engagement_profile: Dict[str, Any], *, student_rows: list | None = None, endpoint: str, api_key: str = None, model: str = None, temperature: float = 0.2) -> Dict[str, Any]:
    """Call an NVIDIA NIM-compatible HTTP endpoint to generate a study plan.

    This function sends a POST request with a JSON body containing the
    `engagement_profile` and simple instructions. The exact payload may need
    tweaking to match your NIM deployment.
    """
    if requests is None:
        raise RuntimeError("requests package is not installed. Install via `pip install requests` to use NIM provider.")

    if not endpoint:
        raise ValueError("nim endpoint must be provided when using NIM provider")

    # Use API key from env if not passed explicitly
    key = api_key or os.environ.get("NIM_API_KEY")
    if not key:
        raise RuntimeError("NIM_API_KEY not provided via --nim_key or NIM_API_KEY env var")

    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }

    # Simple prompt + payload. Adjust `payload` to match your NIM model's expected schema.
    prompt = (
        "Produce a JSON 7-day study plan based on the provided engagement profile. "
        "Return only JSON with keys: student_id, engagement_profile, daily_minutes, days (7 items)."
    )

    payload = {
        "model": model,
        "temperature": temperature,
        "prompt": prompt,
        "engagement_profile": engagement_profile,
    }
    if student_rows is not None:
        payload["student_rows"] = student_rows

    resp = requests.post(endpoint, headers=headers, json=payload, timeout=30)
    try:
        resp.raise_for_status()
    except Exception as exc:
        raise RuntimeError(f"NIM request failed: {exc}\nResponse: {resp.text}")

    text = resp.text.strip()
    # attempt to parse JSON response body
    try:
        data = resp.json()
    except Exception:
        # if not JSON, try to parse text as JSON
        try:
            data = json.loads(text)
        except Exception as exc:
            raise RuntimeError(f"Failed to parse JSON from NIM response: {exc}\nResponse text:\n{text}")

    return data


def _save_engagement_csv(df: pd.DataFrame, out_path: str) -> None:
    df.to_csv(out_path, index=False)


def _cli():
    parser = argparse.ArgumentParser(description="Build engagement matrix and generate study plan.")
    parser.add_argument("--input", required=True, help="input CSV file with interaction rows")
    parser.add_argument("--student_id", required=False, help="student id to generate plan for")
    parser.add_argument("--out", default="engagement_matrix.csv", help="output engagement matrix CSV path")
    parser.add_argument("--plan_out", default=None, help="optional write plan JSON to this file")
    parser.add_argument("--use-llm", action="store_true", help="use an LLM to generate the study plan (requires OPENAI_API_KEY and openai package)")
    parser.add_argument("--llm_model", default="gpt-3.5-turbo", help="LLM model to call when --use-llm is set")
    parser.add_argument("--llm_temperature", type=float, default=0.2, help="temperature for the LLM (float)")
    parser.add_argument("--llm_provider", default="openai", choices=["openai", "nim"], help="LLM provider to use when --use-llm is set")
    parser.add_argument("--nim_endpoint", default=None, help="NIM HTTP endpoint (required if --llm_provider nim)")
    parser.add_argument("--nim_key", default=None, help="NIM API key (or set NIM_API_KEY env var). Avoid pasting keys into chats.")

    args = parser.parse_args()
    raw = load_data(args.input)
    print("Columns detected:", list(raw.columns))
    eng = build_engagement_matrix(raw)
    _save_engagement_csv(eng, args.out)
    print(f"Saved engagement matrix to {args.out}")

    if args.student_id:
        # Coerce student_id type to match engagement matrix index where possible
        sid_arg = args.student_id
        try:
            if "student_id" in eng.columns and pd.api.types.is_integer_dtype(eng["student_id"]):
                sid_arg = int(args.student_id)
        except Exception:
            sid_arg = args.student_id
        plan = generate_study_plan(eng, sid_arg)

        if args.use_llm:
            try:
                profile = plan.get("engagement_profile")
                if profile is None:
                    raise RuntimeError("unable to extract engagement_profile for LLM")
                # Provide raw rows for the selected student to the provider for richer, student-specific plans
                sid_col = None
                try:
                    sid_col = _guess_columns(raw).get("student_id")
                except Exception:
                    sid_col = None

                student_rows = None
                if sid_col and sid_col in raw.columns:
                    student_rows = raw[raw[sid_col].astype(str) == str(args.student_id)].to_dict(orient="records")

                if args.llm_provider == "openai":
                    plan = generate_study_plan_with_llm(profile, student_rows=student_rows, model=args.llm_model, temperature=args.llm_temperature)
                else:  # nim
                    plan = generate_study_plan_with_nim(profile, student_rows=student_rows, endpoint=args.nim_endpoint, api_key=args.nim_key, model=args.llm_model, temperature=args.llm_temperature)
            except Exception as e:
                print("LLM generation failed:", e)
                print("Falling back to deterministic plan.")
                plan = generate_study_plan(eng, args.student_id)

        print(json.dumps(plan, indent=2))
        if args.plan_out:
            with open(args.plan_out, "w", encoding="utf-8") as f:
                json.dump(plan, f, indent=2)


if __name__ == "__main__":
    _cli()
