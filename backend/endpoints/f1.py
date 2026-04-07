from fastapi import APIRouter, HTTPException
from typing import List
import requests

router = APIRouter(tags=["f1"])

# Jolpica API base URL
JOLPICA_BASE_URL = "https://jolpica-formula1.p.rapidapi.com"


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
