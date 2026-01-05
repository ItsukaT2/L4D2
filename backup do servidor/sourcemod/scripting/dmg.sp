#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <gamma_colors>

#pragma newdecls required

public Plugin myinfo = {
    name = "L4D2 Fortnite Damage (Dmgfx Fix - Part 1)",
    author = "AI Assistant",
    description = "Soma shotgun, Diretorio dmgfx, Limite 5 e Spawn",
    version = "54.0"
}


int ge_iOwner[2048];




bool g_bState[MAXPLAYERS+1]; 
Handle g_hCookie;
bool g_bSlotForceFade[MAXPLAYERS + 1][5]; 

int g_iNextSlot[MAXPLAYERS+1];
int g_iShotgunSum[MAXPLAYERS+1];
bool g_bShotgunActive[MAXPLAYERS+1];
bool g_bShotgunCrit[MAXPLAYERS+1];
float g_vShotgunPos[MAXPLAYERS+1][3]; // Salva onde o primeiro balim pegou

ConVar g_cvScale, g_cvSpacing;
char g_sSpritePath[] = "materials/dmgfx/numbers.vmt"; 

public void OnPluginStart() {
    g_cvScale = CreateConVar("sm_damage_scale", "0.08", "Escala base");
    g_cvSpacing = CreateConVar("sm_damage_spacing", "7.0", "Distancia");
    RegConsoleCmd("sm_hits", Command_ToggleHits);
    g_hCookie = RegClientCookie("fortnite_hits_state", "Estado", CookieAccess_Protected);
    HookEvent("player_hurt", Event_Damage);
    HookEvent("infected_hurt", Event_Damage);
}

public void OnMapStart() { 
    PrecacheModel(g_sSpritePath, true); 
    AddFileToDownloadsTable("materials/dmgfx/numbers.vmt"); 
    AddFileToDownloadsTable("materials/dmgfx/numbers.vtf"); 
}

public void OnClientCookiesCached(int client) {
    char buff[4]; GetClientCookie(client, g_hCookie, buff, sizeof(buff));
    g_bState[client] = (buff[0] == '\0' || StringToInt(buff) == 1);
}


public Action Command_ToggleHits(int client, int args) {
    if (client == 0) return Plugin_Handled;
    g_bState[client] = !g_bState[client];
    char b[4]; IntToString(g_bState[client], b, sizeof(b)); SetClientCookie(client, g_hCookie, b);
    GCPrintToChat(client, "{default}[{green}HITS{default}] %s", g_bState[client] ? "{green}ATIVADO" : "{red}DESATIVADO");
    return Plugin_Handled;
}

// --- VISIBILIDADE (SÓ O AGRESSOR VÊ) ---
public Action OnTransmit(int entity, int client) {
    // Se o cliente tentando ver não for EXATAMENTE o dono do sprite, bloqueia.
    if (ge_iOwner[entity] != client) {
        return Plugin_Stop; 
    }
    return Plugin_Continue;
}

public Action Timer_Collect(Handle timer, DataPack pack) {
    pack.Reset();
    int attacker = GetClientOfUserId(pack.ReadCell());
    int victim = pack.ReadCell();
    // REMOVIDO: delete pack; (O CreateDataTimer já faz isso)

    if (attacker > 0 && IsValidEntity(victim)) {
        SpawnEverything(attacker, g_iShotgunSum[attacker], victim, g_bShotgunCrit[attacker], true);
        
        g_iShotgunSum[attacker] = 0;
        g_bShotgunActive[attacker] = false;
    }
    return Plugin_Stop;
}

public Action Timer_CollectShotgun(Handle timer, DataPack pack) {
    pack.Reset();
    int attacker = GetClientOfUserId(pack.ReadCell());
    int victim = pack.ReadCell();
    // REMOVIDO: delete pack; (O CreateDataTimer já faz isso)

    if (attacker > 0 && IsClientInGame(attacker)) {
        SpawnEverything(attacker, g_iShotgunSum[attacker], victim, g_bShotgunCrit[attacker], true);
        
        g_iShotgunSum[attacker] = 0;
        g_bShotgunActive[attacker] = false;
        g_bShotgunCrit[attacker] = false;
    }
    return Plugin_Stop;
}

// --- MOVIMENTO NATURAL (REQUESTFRAME) ---
public void Frame_MasterLogic(DataPack pack) {
    pack.Reset();
    int attacker = GetClientOfUserId(pack.ReadCell());
    int len = pack.ReadCell();
    int ticks = pack.ReadCell();
    int alpha = pack.ReadCell();
    float p[3]; p[0] = pack.ReadFloat(); p[1] = pack.ReadFloat(); p[2] = pack.ReadFloat();
    float hVel = pack.ReadFloat(); float vVel = pack.ReadFloat();
    int slot = pack.ReadCell();

    // Ler os sprites para um array local antes de resetar o pack para escrita
    int sprites[16];
    for (int i = 0; i < len; i++) sprites[i] = pack.ReadCell();

    if (attacker <= 0 || !IsClientInGame(attacker) || alpha <= 10) {
        for (int i = 0; i < len; i++) {
            int ent = EntRefToEntIndex(sprites[i]);
            if (ent > MaxClients && IsValidEntity(ent)) AcceptEntityInput(ent, "Kill");
        }
        delete pack; return;
    }

    ticks++; 
    alpha -= (g_bSlotForceFade[attacker][slot] ? 40 : 8); 
    vVel -= 0.6; p[2] += vVel;

    float vEyePos[3], vEyeAng[3], vRight[3];
    GetClientEyePosition(attacker, vEyePos); GetClientEyeAngles(attacker, vEyeAng);
    GetAngleVectors(vEyeAng, NULL_VECTOR, vRight, NULL_VECTOR);
    p[0] += vRight[0] * hVel; p[1] += vRight[1] * hVel;

    // AQUI ESTAVA O ERRO: Reescrever o pack corretamente para o próximo frame
    pack.Reset();
    pack.WriteCell(GetClientUserId(attacker));
    pack.WriteCell(len);
    pack.WriteCell(ticks);
    pack.WriteCell(alpha);
    pack.WriteFloat(p[0]); pack.WriteFloat(p[1]); pack.WriteFloat(p[2]);
    pack.WriteFloat(hVel); pack.WriteFloat(vVel);
    pack.WriteCell(slot);
    for (int i = 0; i < len; i++) pack.WriteCell(sprites[i]);

    float split = (ticks > 25) ? (float(ticks - 25) * 1.5) : 0.0;

    for (int i = 0; i < len; i++) {
        int sprite = EntRefToEntIndex(sprites[i]);
        if (sprite <= MaxClients || !IsValidEntity(sprite)) continue;
        
        float offset = (float(i) - (float(len - 1) / 2.0)) * (g_cvSpacing.FloatValue + split);
        float dPos[3];
        dPos[0] = p[0] + (vRight[0] * offset); dPos[1] = p[1] + (vRight[1] * offset); dPos[2] = p[2];

        float lookAng[3], lookVec[3];
        MakeVectorFromPoints(dPos, vEyePos, lookVec);
        GetVectorAngles(lookVec, lookAng);
        lookAng[0] *= -1.0; lookAng[1] += 180.0;

        TeleportEntity(sprite, dPos, lookAng, NULL_VECTOR);
        
        // Escala Baseada na Distancia
        float dist = GetVectorDistance(vEyePos, dPos);
        float dynamicScale = (dist / 450.0) * g_cvScale.FloatValue;
        if (ticks <= 6) dynamicScale *= (0.5 + (float(ticks) * 0.15));
        
        SetVariantFloat(dynamicScale); AcceptEntityInput(sprite, "SetScale");

        int r, g, b, a_old; GetEntityRenderColor(sprite, r, g, b, a_old);
        SetEntityRenderColor(sprite, r, g, b, (alpha < 0 ? 0 : alpha));
    }
    RequestFrame(Frame_MasterLogic, pack);
}

void SpawnEverything(int attacker, int damage, int victim, bool crit, bool isShotgun) {
    char sDmg[16]; 
    IntToString(damage, sDmg, sizeof(sDmg));
    int len = strlen(sDmg); 
    float vPos[3]; // USANDO: Variável de posição
    
    // USANDO: isShotgun e victim para definir onde o número nasce
    if (isShotgun) {
        vPos[0] = g_vShotgunPos[attacker][0];
        vPos[1] = g_vShotgunPos[attacker][1];
        vPos[2] = g_vShotgunPos[attacker][2];
    } else {
        if (victim > 0 && victim <= MaxClients) GetClientAbsOrigin(victim, vPos);
        else GetEntPropVector(victim, Prop_Send, "m_vecOrigin", vPos);
    }
    vPos[2] += 55.0;

    // USANDO: attacker, victim e crit para definir a cor
    int r = 255, g = 255, b = 255;
    if (victim > 0 && victim <= MaxClients && GetClientTeam(attacker) == GetClientTeam(victim)) {
        r = 255; g = 0; b = 0; // Vermelho se for Team Kill
    } else if (crit) {
        r = 255; g = 255; b = 0; // Amarelo se for Crítico
    }

    // Preparando o envio para o movimento suave
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(attacker));
    pack.WriteCell(len);
    pack.WriteCell(0);    // Ticks
    pack.WriteCell(255);  // Alpha
    pack.WriteFloat(vPos[0]); pack.WriteFloat(vPos[1]); pack.WriteFloat(vPos[2]);
    pack.WriteFloat(GetRandomFloat(-3.5, 3.5)); // hVel
    pack.WriteFloat(10.0); // vVel
    
    int slot = g_iNextSlot[attacker];
    pack.WriteCell(slot);
    g_bSlotForceFade[attacker][slot] = false;

    for (int i = 0; i < len; i++) {
        int sprite = CreateEntityByName("env_sprite_oriented");
        if (sprite == -1) continue;
        
        ge_iOwner[sprite] = attacker; // USANDO: attacker aqui para visibilidade
        DispatchKeyValue(sprite, "model", g_sSpritePath);
        DispatchKeyValue(sprite, "rendermode", "1"); 
        DispatchSpawn(sprite);
        
        SetEntPropFloat(sprite, Prop_Data, "m_flFrame", float(sDmg[i] - '0'));
        SetEntityRenderColor(sprite, r, g, b, 255); // USANDO: r, g, b aqui

        SDKHook(sprite, SDKHook_SetTransmit, OnTransmit);
        pack.WriteCell(EntIndexToEntRef(sprite));
    }
    
    g_iNextSlot[attacker] = (slot + 1) % 5;
    RequestFrame(Frame_MasterLogic, pack);
}

public void Event_Damage(Event event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = (StrEqual(name, "player_hurt")) ? GetClientOfUserId(event.GetInt("userid")) : event.GetInt("entityid");

    if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker) || IsFakeClient(attacker) || attacker == victim || !g_bState[attacker]) 
        return;

    int damage = event.GetInt("amount"); 
    if (damage <= 0) damage = event.GetInt("dmg_health");

    // --- FIX PARA WITCH E COMMONS ---
    char weapon[32]; 
    event.GetString("weapon", weapon, sizeof(weapon));

    // Se o nome da arma vier vazio (comum em Witch/Infected), pegamos a arma ativa do jogador
    if (weapon[0] == '\0') {
        int iWep = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
        if (iWep > 0 && IsValidEntity(iWep)) {
            GetEntityClassname(iWep, weapon, sizeof(weapon));
        }
    }

    // Verifica se é shotgun (agora detecta chrome, spas, pump e auto)
    bool isShotgun = (StrContains(weapon, "shotgun") != -1 || StrContains(weapon, "spas") != -1);

    if (isShotgun) {
        if (!g_bShotgunActive[attacker]) {
            g_bShotgunActive[attacker] = true;
            g_iShotgunSum[attacker] = damage;
            g_bShotgunCrit[attacker] = (event.GetInt("hitgroup") == 1);
            
            if (victim > 0 && IsValidEntity(victim)) {
                if (victim <= MaxClients) GetClientAbsOrigin(victim, g_vShotgunPos[attacker]);
                else GetEntPropVector(victim, Prop_Send, "m_vecOrigin", g_vShotgunPos[attacker]);
            }

            DataPack pack = new DataPack();
            // Aumentamos levemente para 0.15 para garantir que pegue todos os balins de longe
            CreateDataTimer(0.15, Timer_CollectShotgun, pack); 
            pack.WriteCell(GetClientUserId(attacker));
            pack.WriteCell(victim);
        } else {
            g_iShotgunSum[attacker] += damage;
            if (event.GetInt("hitgroup") == 1) g_bShotgunCrit[attacker] = true;
        }
    } else {
        SpawnEverything(attacker, damage, victim, (event.GetInt("hitgroup") == 1), false);
    }
}

public bool Filter_World(int entity, int mask) { return (entity == 0); }