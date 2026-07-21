-- Database values are intentionally omitted. TFS reads MYSQL_* from the process environment.
ip = os.getenv("TFS_IP") or "127.0.0.1"
bindOnlyGlobalAddress = false
loginProtocolPort = tonumber(os.getenv("TFS_LOGIN_PORT") or "7171")
gameProtocolPort = tonumber(os.getenv("TFS_GAME_PORT") or "7172")
statusProtocolPort = tonumber(os.getenv("TFS_STATUS_PORT") or "7171")
mapName = os.getenv("TFS_MAP_NAME") or "forgotten"

-- TFS v1.6 protocol 13.10 is compiled into server/src/definitions.h.
serverName = "OTServ"
worldType = "pvp"
maxPlayers = 0
