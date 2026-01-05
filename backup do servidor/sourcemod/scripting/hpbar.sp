#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <gamma_colors>

#pragma newdecls required



public Plugin myinfo = {
    name = "L4D2 Fortnite Health Bar (Full Fix)",
    author = "AI Assistant",
    description = "Barra alta, cor preta na morte e sem bugs",
    version = "2.3"
}


float g_fBlockBar[2048]; // Armazena o tempo de bloqueio por vítima
int g_iNextBarSlot[MAXPLAYERS+1]; 
float g_fNextAllowedBar[MAXPLAYERS+1][2048];
int ge_iOwner[2048];
bool g_bState[MAXPLAYERS+1];
Handle g_hCookie;
int g_iSlotSpriteRef[MAXPLAYERS+1][5]; // Guarda o Ref do Sprite nos 5 slots
int g_iSlotVictim[MAXPLAYERS+1][5];    // Guarda quem é a vítima de cada slot

char g_sBarPath[] = "materials/hpbar/bar.vmt";
#define BAR_HEIGHT 90.0

public void OnPluginStart() {
    RegConsoleCmd("sm_bars", Command_ToggleBars);
    g_hCookie = RegClientCookie("fortnite_bars_state", "Estado das barras", CookieAccess_Protected);
    HookEvent("player_hurt", Event_Damage);
    HookEvent("infected_hurt", Event_Damage);
}


public void OnMapStart() {
    PrecacheModel(g_sBarPath, true);
    AddFileToDownloadsTable("materials/hpbar/bar.vmt");
    AddFileToDownloadsTable("materials/hpbar/bar.vtf");
}

public void OnClientCookiesCached(int client) {
    char buff[4]; GetClientCookie(client, g_hCookie, buff, sizeof(buff));
    g_bState[client] = (buff[0] == '\0' || StringToInt(buff) == 1);
}

public Action Command_ToggleBars(int client, int args) {
    if (client == 0) return Plugin_Handled;
    g_bState[client] = !g_bState[client];
    char b[4]; IntToString(g_bState[client], b, sizeof(b)); SetClientCookie(client, g_hCookie, b);
    GCPrintToChat(client, "{default}[{green}BARS{default}] Barra: %s", g_bState[client] ? "{green}ON" : "{red}OFF");
    return Plugin_Handled;
}



public Action OnTransmit(int entity, int client) {
    if (ge_iOwner[entity] != client) return Plugin_Stop;
    return Plugin_Continue;
}

public void Frame_HealthLogic(DataPack pack) {
    pack.Reset();
    int attackerUserId = pack.ReadCell();
    int attacker = GetClientOfUserId(attackerUserId);
    int victim = pack.ReadCell(); 
    int ticks = pack.ReadCell();
    int alpha = pack.ReadCell();
    int spriteRef = pack.ReadCell();
    int maxHP = pack.ReadCell();
    int slot = pack.ReadCell();
    
    int sprite = EntRefToEntIndex(spriteRef);

    // 1. Condição de término (Alpha baixo ou entidade inválida)
    if (sprite <= 0 || !IsValidEntity(sprite) || attacker <= 0 || !IsClientInGame(attacker) || alpha <= 5) {
        if (sprite > 0 && IsValidEntity(sprite)) AcceptEntityInput(sprite, "Kill");
        
        // Aplica o bloqueio de 10 segundos ao fechar a barra se a vítima morreu
        if (victim > 0 && victim < 2048) g_fBlockBar[victim] = GetGameTime() + 10.0;
        
        if (attacker > 0 && g_iSlotSpriteRef[attacker][slot] == spriteRef) {
            g_iSlotVictim[attacker][slot] = 0;
            g_iSlotSpriteRef[attacker][slot] = 0;
        }
        delete pack; return;
    }

    if (g_iSlotSpriteRef[attacker][slot] != spriteRef) {
        delete pack; return;
    }

    ticks++;
    bool victimValid = false;
    int curHP = 0;

    // 2. Checagem de vida e estado (Dying Fix)
    if (victim > 0 && IsValidEntity(victim)) {
        curHP = GetEntProp(victim, Prop_Data, "m_iHealth");
        bool isDying = (victim <= MaxClients) ? !IsPlayerAlive(victim) : (GetEntProp(victim, Prop_Data, "m_lifeState") != 0);

        if (curHP > 0 && !isDying) victimValid = true;
    }

    float vPos[3];
    if (victimValid) {
        // --- VÍTIMA VIVA: ATUALIZAÇÃO NORMAL ---
        GetEntPropVector(victim, Prop_Send, "m_vecOrigin", vPos);
        vPos[2] += BAR_HEIGHT;
        
        float pct = float(curHP) / float(maxHP);
        if (pct > 1.0) pct = 1.0;
        int frame = RoundToCeil(pct * 10.0);
        if (frame < 1 && curHP > 0) frame = 1; if (frame > 10) frame = 10;
        SetEntPropFloat(sprite, Prop_Data, "m_flFrame", float(frame));

        if (pct > 0.5) SetEntityRenderColor(sprite, 0, 255, 0, alpha);
        else if (pct > 0.2) SetEntityRenderColor(sprite, 255, 255, 0, alpha);
        else SetEntityRenderColor(sprite, 255, 0, 0, alpha);
        
        if (ticks > 70) alpha -= 10;
    } else {
        // --- MORTE: VAI PARA O PRETO (FRAME 0) E SOME FLUIDO ---
        alpha -= 40; 
        SetEntPropFloat(sprite, Prop_Data, "m_flFrame", 0.0); // Mostra frame preto
        SetEntityRenderColor(sprite, 255, 255, 255, (alpha < 0 ? 0 : alpha)); // Remove filtro vermelho
        
        if (victim > 0 && IsValidEntity(victim)) {
            GetEntPropVector(victim, Prop_Send, "m_vecOrigin", vPos);
            vPos[2] += BAR_HEIGHT;
        } else {
            GetEntPropVector(sprite, Prop_Send, "m_vecOrigin", vPos);
        }
    }

    // 3. Posicionamento e Escala
    float vEyePos[3], lookAng[3], lookVec[3];
    GetClientEyePosition(attacker, vEyePos);
    MakeVectorFromPoints(vPos, vEyePos, lookVec);
    GetVectorAngles(lookVec, lookAng);
    lookAng[0] *= -1.0; lookAng[1] += 180.0;
    TeleportEntity(sprite, vPos, lookAng, NULL_VECTOR);

    float scale = (GetVectorDistance(vEyePos, vPos) / 500.0) * 0.22;
    if (scale < 0.08) scale = 0.08;
    SetVariantFloat(scale); AcceptEntityInput(sprite, "SetScale");

    pack.Reset();
    pack.WriteCell(attackerUserId); pack.WriteCell(victim); pack.WriteCell(ticks);
    pack.WriteCell(alpha); pack.WriteCell(spriteRef); pack.WriteCell(maxHP); pack.WriteCell(slot);
    RequestFrame(Frame_HealthLogic, pack);
}

public void Event_Damage(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = (StrEqual(name, "player_hurt")) ? GetClientOfUserId(event.GetInt("userid")) : event.GetInt("entityid");

    if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker) || attacker == victim || !g_bState[attacker])
        return;

    if (victim <= 0 || victim >= 2048 || !IsValidEntity(victim)) return;
    if (victim <= MaxClients && GetClientTeam(attacker) == GetClientTeam(victim)) return;

    // Trava para não criar 10 timers para o MESMO zumbi (shotgun fix)
    float currentTime = GetGameTime();
    if (currentTime < g_fNextAllowedBar[attacker][victim]) return;
    g_fNextAllowedBar[attacker][victim] = currentTime + 0.12; 

    // RESERVA O SLOT AQUI (Resolve o problema de aparecer só um Common)
    int slot = g_iNextBarSlot[attacker];
    g_iNextBarSlot[attacker] = (slot + 1) % 5;

    DataPack pack;
    CreateDataTimer(0.1, Timer_CreateBar, pack);
    pack.WriteCell(GetClientUserId(attacker));
    pack.WriteCell(victim);
    pack.WriteCell(slot); // Passa o slot reservado para o Timer
}

public Action Timer_CreateBar(Handle timer, DataPack pack) {
    pack.Reset();
    int attackerUserId = pack.ReadCell();
    int attacker = GetClientOfUserId(attackerUserId);
    int victim = pack.ReadCell();
    int slot = pack.ReadCell();

    if (attacker <= 0 || !IsClientInGame(attacker) || !IsValidEntity(victim)) return Plugin_Stop;

    // Bloqueia a criação se o bicho estiver nos 10 segundos de "morte"
    if (GetGameTime() < g_fBlockBar[victim]) return Plugin_Stop;

    // Se já existe barra ativa para esse bicho, não cria outra
    for (int i = 0; i < 5; i++) {
        if (g_iSlotVictim[attacker][i] == victim) {
            int check = EntRefToEntIndex(g_iSlotSpriteRef[attacker][i]);
            if (check != -1 && IsValidEntity(check)) return Plugin_Stop;
        }
    }

    int oldEnt = EntRefToEntIndex(g_iSlotSpriteRef[attacker][slot]);
    if (oldEnt > MaxClients && IsValidEntity(oldEnt)) AcceptEntityInput(oldEnt, "Kill");

    int maxHP = GetEntProp(victim, Prop_Data, "m_iMaxHealth");
    if (maxHP <= 1) {
        char cls[64]; GetEntityClassname(victim, cls, sizeof(cls));
        if (StrEqual(cls, "infected")) maxHP = 50;
        else if (StrEqual(cls, "witch")) maxHP = 1000;
        else maxHP = GetEntProp(victim, Prop_Data, "m_iHealth");
    }
    if (maxHP <= 0) maxHP = 100;

    int sprite = CreateEntityByName("env_sprite_oriented");
    if (sprite == -1) return Plugin_Stop;

    ge_iOwner[sprite] = attacker;
    SetEdictFlags(sprite, GetEdictFlags(sprite) & ~FL_EDICT_ALWAYS);
    DispatchKeyValue(sprite, "model", g_sBarPath);
    DispatchKeyValue(sprite, "rendermode", "1");
    DispatchSpawn(sprite);
    SDKHook(sprite, SDKHook_SetTransmit, OnTransmit);

    int spriteRef = EntIndexToEntRef(sprite);
    g_iSlotSpriteRef[attacker][slot] = spriteRef;
    g_iSlotVictim[attacker][slot] = victim;

    DataPack fPack = new DataPack();
    fPack.WriteCell(attackerUserId);
    fPack.WriteCell(victim);
    fPack.WriteCell(0); fPack.WriteCell(255);
    fPack.WriteCell(spriteRef);
    fPack.WriteCell(maxHP);
    fPack.WriteCell(slot);
    RequestFrame(Frame_HealthLogic, fPack);

    return Plugin_Stop;
}