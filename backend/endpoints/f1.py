from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List
import requests

from services.auth import get_current_user
from models.user import User

router = APIRouter(tags=["f1"])

# Jolpica API base URL
JOLPICA_BASE_URL = "https://jolpica-formula1.p.rapidapi.com"

# Lazy-initialized F1DataService singleton
_data_service = None


def _get_data_service():
    global _data_service
    if _data_service is None:
        from agents.data_service import F1DataService
        _data_service = F1DataService()
    return _data_service


@router.get("/drivers", response_model=List[str])
async def get_current_drivers():
    """Get list of current F1 drivers"""
    try:
        # Using Jolpica API to get current season drivers
        response = requests.get(f"{JOLPICA_BASE_URL}/drivers.json")
        if response.status_code != 200:
            # Fallback to mock data if API fails
            return [
                "Max Verstappen",
                "Sergio Pérez",
                "Lewis Hamilton",
                "George Russell",
                "Charles Leclerc",
                "Carlos Sainz",
                "Lando Norris",
                "Oscar Piastri",
                "Fernando Alonso",
                "Lance Stroll",
                "Esteban Ocon",
                "Pierre Gasly",
                "Yuki Tsunoda",
                "Daniel Ricciardo",
                "Kevin Magnussen",
                "Nico Hülkenberg",
                "Alexander Albon",
                "Logan Sargeant",
                "Valtteri Bottas",
                "Guanyu Zhou",
            ]

        data = response.json()
        drivers = []
        for driver_data in (
            data.get("MRData", {}).get("DriverTable", {}).get("Drivers", [])
        ):
            full_name = f"{driver_data.get('givenName', '')} {driver_data.get('familyName', '')}".strip()
            if full_name:
                drivers.append(full_name)

        return drivers if drivers else ["Max Verstappen", "Lewis Hamilton"]  # Fallback
    except Exception as e:
        # Return mock data on error
        return [
            "Max Verstappen",
            "Sergio Pérez",
            "Lewis Hamilton",
            "George Russell",
            "Charles Leclerc",
            "Carlos Sainz",
            "Lando Norris",
            "Oscar Piastri",
            "Fernando Alonso",
            "Lance Stroll",
            "Esteban Ocon",
            "Pierre Gasly",
            "Yuki Tsunoda",
            "Daniel Ricciardo",
            "Kevin Magnussen",
            "Nico Hülkenberg",
            "Alexander Albon",
            "Logan Sargeant",
            "Valtteri Bottas",
            "Guanyu Zhou",
        ]


@router.get("/teams", response_model=List[str])
async def get_current_teams():
    """Get list of current F1 teams"""
    try:
        # Using Jolpica API to get current season constructors/teams
        response = requests.get(f"{JOLPICA_BASE_URL}/constructors.json")
        if response.status_code != 200:
            # Fallback to mock data if API fails
            return [
                "Red Bull Racing",
                "Mercedes",
                "Ferrari",
                "McLaren",
                "Aston Martin",
                "Alpine",
                "Williams",
                "RB",
                "Haas F1 Team",
                "Kick Sauber",
            ]

        data = response.json()
        teams = []
        for constructor_data in (
            data.get("MRData", {}).get("ConstructorTable", {}).get("Constructors", [])
        ):
            team_name = constructor_data.get("name", "")
            if team_name:
                teams.append(team_name)

        return teams if teams else ["Red Bull Racing", "Mercedes"]  # Fallback
    except Exception as e:
        # Return mock data on error
        return [
            "Red Bull Racing",
            "Mercedes",
            "Ferrari",
            "McLaren",
            "Aston Martin",
            "Alpine",
            "Williams",
            "RB",
            "Haas F1 Team",
            "Kick Sauber",
        ]


# ---------------------------------------------------------------------------
# Standings & Results endpoints
# ---------------------------------------------------------------------------


@router.get("/standings/drivers")
def get_driver_standings(
    season: int = Query(default=2025),
    current_user: User = Depends(get_current_user),
) -> List[dict]:
    data_service = _get_data_service()
    return data_service.get_driver_standings(season)


@router.get("/standings/constructors")
def get_constructor_standings(
    season: int = Query(default=2025),
    current_user: User = Depends(get_current_user),
) -> List[dict]:
    data_service = _get_data_service()
    return data_service.get_constructor_standings(season)


@router.get("/race-results/{season}/{round_num}")
def get_race_results(
    season: int,
    round_num: int,
    current_user: User = Depends(get_current_user),
) -> dict:
    data_service = _get_data_service()
    return data_service.get_race_results(season, round_num)


@router.get("/driver-dashboard")
def get_driver_dashboard(
    current_user: User = Depends(get_current_user),
) -> dict:
    fav_driver = current_user.fav_driver
    if not fav_driver:
        return {"error": "No favourite driver set"}

    data_service = _get_data_service()

    # Championship position & points
    standings = data_service.get_driver_standings()
    championship_position = None
    championship_points = None
    for s in standings:
        driver_name = f"{s.get('givenName', '')} {s.get('familyName', '')}".strip()
        if fav_driver.lower() in driver_name.lower() or fav_driver.lower() in s.get("familyName", "").lower():
            championship_position = int(s.get("position", 0))
            championship_points = float(s.get("points", 0))
            break

    # Last race
    last_race = None
    season_results = data_service.get_driver_season_results(fav_driver)
    if season_results:
        last = season_results[-1]
        last_race = {
            "race_name": last.get("race_name", last.get("raceName", "")),
            "position": int(last.get("position", 0)),
            "points": float(last.get("points", 0)),
        }

    # Next race
    next_race_data = data_service.get_next_race()
    next_race = None
    if next_race_data:
        next_race = {
            "race_name": next_race_data.get("raceName", ""),
            "circuit_name": next_race_data.get("circuitName", ""),
            "date": next_race_data.get("date", ""),
        }

    return {
        "driver_id": fav_driver,
        "championship_position": championship_position,
        "championship_points": championship_points,
        "last_race": last_race,
        "next_race": next_race,
    }


@router.get("/next-race")
def get_next_race() -> dict:
    data_service = _get_data_service()
    return data_service.get_next_race()
