#define MAX_VEHSPAWN_POINT (50)

enum spawnPointData {
    sID,
    sName[32],
    Float:sPos[3],
    sWorld,
    sInterior,
    sFaction,
    sPickup,
    Text3D:sText
};

new VehSpawnPoint[MAX_VEHSPAWN_POINT][spawnPointData],
    Iterator:SpawnPoints<MAX_VEHSPAWN_POINT>;

#include <YSI\y_hooks>
hook OnGameModeInitEx() {
    mysql_tquery(g_SQL,"SELECT * FROM `vehspawnpoint`", "SpawnPoint_Load", "");
    return 1;
}

hook OnGameModeExit() {
    foreach (new i : SpawnPoints) {
        SpawnPoint_Save(i);
    }
    return 1;
}

Function:SpawnPoint_Load() {
    new rows = cache_num_rows();

    for (new i = 0; i < rows; i ++) {
        Iter_Add(SpawnPoints, i);

        cache_get_value_int(i, "ID", VehSpawnPoint[i][sID]);
        cache_get_value(i, "Name", VehSpawnPoint[i][sName]);
        cache_get_value_float(i, "X", VehSpawnPoint[i][sPos][0]);
        cache_get_value_float(i, "Y", VehSpawnPoint[i][sPos][1]);
        cache_get_value_float(i, "Z", VehSpawnPoint[i][sPos][2]);
        cache_get_value_int(i, "World", VehSpawnPoint[i][sWorld]);
        cache_get_value_int(i, "Interior", VehSpawnPoint[i][sInterior]);
        cache_get_value_int(i, "Faction", VehSpawnPoint[i][sFaction]);

        SpawnPoint_Refresh(i);
    }
    printf("*** [R:RP Database: Loaded] veh spawn point data loaded (%d count)", rows);
    return 1;
}

Function:OnSpawnPointCreated(id) {
    if (!Iter_Contains(SpawnPoints, id))
        return 0;
    
    VehSpawnPoint[id][sID] = cache_insert_id();
    SpawnPoint_Save(id);
    return 1;
}

SpawnPoint_Create(name[], Float:x, Float:y, Float:z, vw = 0, int = 0, faction = 0) {
    new id = Iter_Free(SpawnPoints);

    if (id != cellmin) {
        Iter_Add(SpawnPoints, id);

        format(VehSpawnPoint[id][sName], 32, name);
        VehSpawnPoint[id][sPos][0] = x;
        VehSpawnPoint[id][sPos][1] = y;
        VehSpawnPoint[id][sPos][2] = z;
        VehSpawnPoint[id][sWorld] = vw;
        VehSpawnPoint[id][sInterior] = int;
        VehSpawnPoint[id][sFaction] = faction;

        SpawnPoint_Refresh(id);

        mysql_tquery(g_SQL, sprintf("INSERT INTO `vehspawnpoint` (`World`) VALUES ('%d')", vw), "OnSpawnPointCreated", "d", id);
        return id;
    }
    return cellmin;
}

SpawnPoint_Refresh(id) {
    if (!Iter_Contains(SpawnPoints, id))
        return 0;
    
    if (IsValidDynamicPickup(VehSpawnPoint[id][sPickup]))
        DestroyDynamicPickup(VehSpawnPoint[id][sPickup]);
    
    if (IsValidDynamic3DTextLabel(VehSpawnPoint[id][sText]))
        DestroyDynamic3DTextLabel(VehSpawnPoint[id][sText]);
    
    new string[256];
    format(string,sizeof(string),"[VehicleSpawner:%d]\n"GREEN_E"%s\n"WHITE_E"Type '/spawn' to spawning static vehicle\nType '/despawn' to despawning your current vehicle",id,VehSpawnPoint[id][sName]);
    VehSpawnPoint[id][sPickup] = CreateDynamicPickup(1239, 23, VehSpawnPoint[id][sPos][0], VehSpawnPoint[id][sPos][1], VehSpawnPoint[id][sPos][2], VehSpawnPoint[id][sWorld], VehSpawnPoint[id][sInterior]);
    VehSpawnPoint[id][sText] = CreateDynamic3DTextLabel(string, COLOR_CLIENT, VehSpawnPoint[id][sPos][0], VehSpawnPoint[id][sPos][1], VehSpawnPoint[id][sPos][2], 15.0, INVALID_PLAYER_ID, INVALID_VEHICLE_ID, 1, VehSpawnPoint[id][sWorld], VehSpawnPoint[id][sInterior]);
    return 1;
}

SpawnPoint_Save(id) {
    if (!Iter_Contains(SpawnPoints, id))
        return 0;
    
    new query[600];
    format(query,sizeof(query),"UPDATE `vehspawnpoint` SET `Name` = '%s', `X` = '%f', `Y` = '%f', `Z` = '%f', `World` = '%d', `Interior` = '%d', `Faction` = '%d' WHERE `ID` = '%d'", VehSpawnPoint[id][sName], VehSpawnPoint[id][sPos][0], VehSpawnPoint[id][sPos][1], VehSpawnPoint[id][sPos][2], VehSpawnPoint[id][sWorld], VehSpawnPoint[id][sInterior], VehSpawnPoint[id][sFaction], VehSpawnPoint[id][sID]);
    mysql_tquery(g_SQL, query);
    return 1;
}

SpawnPoint_Delete(id) {
    if (!Iter_Contains(SpawnPoints, id))
        return 0;
    
    if (IsValidDynamicPickup(VehSpawnPoint[id][sPickup]))
        DestroyDynamicPickup(VehSpawnPoint[id][sPickup]);
    
    if (IsValidDynamic3DTextLabel(VehSpawnPoint[id][sText]))
        DestroyDynamic3DTextLabel(VehSpawnPoint[id][sText]);

    mysql_tquery(g_SQL, sprintf("DELETE FROM `vehspawnpoint` WHERE `ID` = '%d'", VehSpawnPoint[id][sID]));
    Iter_Remove(SpawnPoints, id);
    return 1;
}

SSCANF:VehSpawnPointMenu(string[]) {
    if (!strcmp(string,"create",true)) return 1;
    else if (!strcmp(string,"delete",true)) return 2;
    else if (!strcmp(string,"name",true)) return 3;
    else if (!strcmp(string,"location",true)) return 4;
    else if (!strcmp(string,"vw",true)) return 5;
    else if (!strcmp(string,"int",true)) return 6;
    else if (!strcmp(string,"faction",true)) return 7;
    else return 0;
}

CMD:vehspawnpoint(playerid, params[]) {
    if(pData[playerid][pAdmin] < 5)
        return Error(playerid, "Don't Acces");
    
    new option, string[128];
    if (sscanf(params, "k<VehSpawnPointMenu>S()[128]", option, string))
        return Usage(playerid, "/vehspawnpoint [create/delete/name/location/vw/int/faction]");
    
    switch (option) {
        case 1: {
            new faction, name[32];
            if (sscanf(string,"ds[32]",faction,name))
                return Usage(playerid, "/vehspawnpoint create [faction id] [name]");
            
            if (strlen(name) > 32 || strlen(name) < 1)
                return Error(playerid, "Name is too long");
            
            if(faction <= 0 || faction >= 6)
                return Error(playerid, "Type only 1-5");
            
            new Float:pos[3];
            GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
            new id = SpawnPoint_Create(name, pos[0], pos[1], pos[2], GetPlayerVirtualWorld(playerid), GetPlayerInterior(playerid), faction);

            if (id == cellmin)
                return Error(playerid, "Failed to create spawn point");
            
            SendCustomMessage(playerid, "VEHSPAWNPOINT", "Vehicle spawn point created with ID: "YELLOW_E"%d", id);
        }
        case 2: {
            new id;
            if (sscanf(string,"d",id))
                return Usage(playerid, "/vehspawnpoint delete [spawnpoint id]");
            
            if (!Iter_Contains(SpawnPoints, id))
                return Error(playerid, "Spawn point doesn't exist");
            
            if (!SpawnPoint_Delete(id))
                return Error(playerid, "Failed to delete spawn point");
            
            SendCustomMessage(playerid, "VEHSPAWNPOINT", "Vehicle spawn point deleted with ID: "YELLOW_E"%d", id);
        }
        case 3: {
            new id, name[32];
            if (sscanf(string,"ds[32]",id,name))
                return Usage(playerid, "/vehspawnpoint name [spawnpoint id] [name]");
            
            if (!Iter_Contains(SpawnPoints, id))
                return Error(playerid, "Spawn point doesn't exist");
            
            if (strlen(name) > 32 || strlen(name) < 1)
                return Error(playerid, "Name is too long");
            
            format(VehSpawnPoint[id][sName],32,name);
            SpawnPoint_Refresh(id);
            SpawnPoint_Save(id);
            SendCustomMessage(playerid, "VEHSPAWNPOINT", "Vehicle spawn point name changed to: "YELLOW_E"%s", name);
        }
        case 4: {
            new id, Float:pos[3];
            if (sscanf(string,"d",id))
                return Usage(playerid, "/vehspawnpoint location [spawnpoint id]");
            
            if (!Iter_Contains(SpawnPoints, id))
                return Error(playerid, "Spawn point doesn't exist");
            
            GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
            VehSpawnPoint[id][sPos][0] = pos[0];
            VehSpawnPoint[id][sPos][1] = pos[1];
            VehSpawnPoint[id][sPos][2] = pos[2];
            SpawnPoint_Refresh(id);
            SpawnPoint_Save(id);
            SendCustomMessage(playerid, "VEHSPAWNPOINT", "Vehicle spawn point location ID: "YELLOW_E"%d "WHITE_E"changed to your current location", id);
        }
        case 5: {
            new id, vw;
            if (sscanf(string,"dd",id,vw))
                return Usage(playerid, "/vehspawnpoint vw [spawnpoint id] [virtual world]");
            
            if (!Iter_Contains(SpawnPoints, id))
                return Error(playerid, "Spawn point doesn't exist");

            VehSpawnPoint[id][sWorld] = vw;
            SpawnPoint_Refresh(id);
            SpawnPoint_Save(id);
            SendCustomMessage(playerid, "VEHSPAWNPOINT", "Vehicle spawn point virtual world ID: "YELLOW_E"%d "WHITE_E"has changed to "YELLOW_E"%d", id, vw);
        }
        case 6: {
            new id, int;
            if (sscanf(string,"dd",id,int))
                return Usage(playerid, "/vehspawnpoint int [spawnpoint id] [interior id]");
            
            if (!Iter_Contains(SpawnPoints, id))
                return Error(playerid, "Spawn point doesn't exist");

            VehSpawnPoint[id][sInterior] = int;
            SpawnPoint_Refresh(id);
            SpawnPoint_Save(id);
            SendCustomMessage(playerid, "VEHSPAWNPOINT", "Vehicle spawn point interior ID: "YELLOW_E"%d "WHITE_E"has changed to "YELLOW_E"%d", id, int);
        }
        case 7: {
            new id, faction;
            if (sscanf(string,"dd",id,faction))
                return Usage(playerid, "/vehspawnpoint faction [spawnpoint id] [faction id]");
            
            if (!Iter_Contains(SpawnPoints, id))
                return Error(playerid, "Spawn point doesn't exist");
            
            if(faction <= 0 || faction >= 6)
                return Error(playerid, "Type only 1-5");

            VehSpawnPoint[id][sFaction] = faction;
            SpawnPoint_Refresh(id);
            SpawnPoint_Save(id);
            SendCustomMessage(playerid, "VEHSPAWNPOINT", "Vehicle spawn point faction ID: "YELLOW_E"%d "WHITE_E"has changed to "YELLOW_E"%d", id, faction);
        }
        default: {
            Usage(playerid, "/vehspawnpoint [create/delete/name/location/vw/int/faction]");
        }
    }
    return 1;
}
/*
CMD:spawn(playerid) 
{
    new factionid = pData[playerid][pFaction];

    //if(factionid == -1 || GetFactionType(playerid) == FACTION_GANG)
    //    return SendErrorMessage(playerid, "You must be a faction member.");

    if (IsPlayerNearVehSpawnPoint(playerid) == -1)
        return SendErrorMessage(playerid, "You are not in range of your faction's vehicle spawn point.");

    new count, string[64 * 70], spawnid = IsPlayerNearVehSpawnPoint(playerid);
    strcat(string, "ID\tUnit\tStatus\n");
    for (new i = 0; i < MAX_DYNAMIC_VEHICLES; i ++) if (Iter_Contains(DynamicVehicles, i) && VehicleData[i][cFaction] == FactionData[factionid][factionID] && VehicleData[i][cStatic] == VehSpawnPoint[spawnid][sID]) {
        strcat(string, sprintf("%d\t%s\t%s\n", i, VehicleData[i][cPlate], (IsValidVehicle(VehicleData[i][cVehicle]) ? (RED_E"Spawned") : (GREEN_E"Available"))));
        ListedFacVehicle[playerid][count++] = i;
    }
    if (count) Dialog_Show(playerid, SpawnVehicle, DIALOG_STYLE_TABLIST_HEADERS, "Vehicle Spawn Point", string, "Spawn", "Cancel");
    else SendErrorMessage(playerid, "There are no vehicles on here.");
    return 1;
}*/
