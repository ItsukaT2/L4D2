#include <sdktools>
#include <sourcemod>

int kills[64];
Handle killTimer[64];
public Plugin myinfo =
{
    name = "KillSound&Mark",
    author = "expvintl",
    description = "A CorssFire Kill Sound & Kill Mark Plugin",
    version = "1.0",
    url = "None"
};
//将击杀图标添加到下载列表中
public void AddKillMarksToDownload(){
    AddFileToDownloadsTable("materials/overlays/cf/1kill.vmt");
    AddFileToDownloadsTable("materials/overlays/cf/1kill.vtf");
    AddFileToDownloadsTable("materials/overlays/cf/2kill.vmt");
    AddFileToDownloadsTable("materials/overlays/cf/2kill.vtf");
    AddFileToDownloadsTable("materials/overlays/cf/3kill.vmt");
    AddFileToDownloadsTable("materials/overlays/cf/3kill.vtf");
    AddFileToDownloadsTable("materials/overlays/cf/4kill.vmt");
    AddFileToDownloadsTable("materials/overlays/cf/4kill.vtf");
    AddFileToDownloadsTable("materials/overlays/cf/5kill.vmt");
    AddFileToDownloadsTable("materials/overlays/cf/5kill.vtf");
    AddFileToDownloadsTable("materials/overlays/cf/6kill.vmt");
    AddFileToDownloadsTable("materials/overlays/cf/6kill.vtf");
    AddFileToDownloadsTable("materials/overlays/cf/headshot.vmt");
    AddFileToDownloadsTable("materials/overlays/cf/headshot.vtf");
    AddFileToDownloadsTable("materials/overlays/cf/boom.vmt");
    AddFileToDownloadsTable("materials/overlays/cf/boom.vtf");
}
//添加音效
public void OnMapStart(){
    AddFileToDownloadsTable("sound/cf/headshot.mp3");
    AddFileToDownloadsTable("sound/cf/kill.mp3");
    AddFileToDownloadsTable("sound/cf/grenadekill.mp3");
    AddFileToDownloadsTable("sound/cf/multikill_2.mp3");
    AddFileToDownloadsTable("sound/cf/multikill_3.mp3");
    AddFileToDownloadsTable("sound/cf/multikill_4.mp3");
    AddFileToDownloadsTable("sound/cf/multikill_5.mp3");
    AddFileToDownloadsTable("sound/cf/multikill_6.mp3");
    AddFileToDownloadsTable("sound/cf/multikill_7.mp3");
    AddFileToDownloadsTable("sound/cf/multikill_8.mp3");
    AddKillMarksToDownload();
}
public void OnPluginStart(){
    //注册死亡事件
    HookEvent("infected_death",Event_InfectedDead);
    HookEvent("player_death",Event_PlayerDeath);
}

public Action Event_InfectedDead(Event event, const char[] name, bool dontBroadcast){
    int attacker=GetClientOfUserId(event.GetInt("attacker"));
    bool isHeadshot=event.GetBool("headshot");
    bool isBlast=event.GetBool("blast");
    //跳过无意义客户端
    if(attacker==0||!IsClientInGame(attacker)||IsFakeClient(attacker)) return Plugin_Handled;
    //爆头时
    if(isHeadshot){
        kills[attacker]++;
        PrecacheSound("cf/headshot.mp3",true);
        EmitSoundToClient(attacker,"cf/headshot.mp3",SOUND_FROM_PLAYER);
        ShowKillMarkOverlay(attacker,0);
        CreateKillTimer(attacker);
        //爆炸致死
    }else if(isBlast){
        PrecacheSound("cf/grenadekill.mp3",true);
        EmitSoundToClient(attacker,"cf/grenadekill.mp3",SOUND_FROM_PLAYER);
        ShowKillMarkOverlay(attacker,7);
        CreateKillTimer(attacker);
        //大于1的击杀
    }else if(kills[attacker]>=1){
        kills[attacker]++;
        char path[64]="";
        if(kills[attacker]>=8){
            Format(path,sizeof(path),"cf/multikill_8.mp3");
        }else{
        Format(path,sizeof(path),"cf/multikill_%d.mp3",kills[attacker]);
        }
        if(kills[attacker]>=6){
            ShowKillMarkOverlay(attacker,6);
        }else{
            ShowKillMarkOverlay(attacker,kills[attacker]);
        }
        PrecacheSound(path,true);
        EmitSoundToClient(attacker,path,SOUND_FROM_PLAYER);
        CreateKillTimer(attacker);
    }
    else{
        //首次非爆头击杀时
        kills[attacker]++;
        PrecacheSound("cf/kill.mp3",true);
        EmitSoundToClient(attacker,"cf/kill.mp3",SOUND_FROM_PLAYER);
        ShowKillMarkOverlay(attacker,1);
        CreateKillTimer(attacker);
    }
    CreateKillTimer(attacker);
    return Plugin_Handled;
}
//当客户端断开时
public void OnClientDisconnect(int client){
    //玩家断开时删除记录
    kills[client]=0;
    killTimer[client]=INVALID_HANDLE;
}
//重置击杀
public Action ResetKillCooldown(Handle handle,int client){
    //击杀冷却到了的时候清除覆盖层
    ClearOverlay(client);
    kills[client]=0;
    killTimer[client]=INVALID_HANDLE;
    return Plugin_Handled;
}
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast){
    int attacker=GetClientOfUserId(event.GetInt("attacker"));
    int killer=GetClientOfUserId(event.GetInt("userid"));
    bool isHeadshot=event.GetBool("headshot");
    //跳过无意义客户端
    if(attacker==0||killer==0||!IsClientInGame(attacker)||IsFakeClient(attacker)||GetClientTeam(attacker)!=2||GetClientTeam(killer)!=3) return Plugin_Handled;
    //被爆头时
    if(isHeadshot){
        kills[attacker]++;
        PrecacheSound("cf/headshot.mp3",true);
        EmitSoundToClient(attacker,"cf/headshot.mp3",SOUND_FROM_PLAYER);
        ShowKillMarkOverlay(attacker,0);
        CreateKillTimer(attacker);
        //当击杀大于1时
    }else if(kills[attacker]>=1){
        kills[attacker]++;
        char path[64];
        //当超过8次击杀以后一直播放最后一段语音
        if(kills[attacker]>=8){
            Format(path,sizeof(path),"cf/multikill_8.mp3");
        }else{
        Format(path,sizeof(path),"cf/multikill_%d.mp3",kills[attacker]);
        }
        //超过6次击杀后一直显示6杀图标
        if(kills[attacker]>=6){
            ShowKillMarkOverlay(attacker,6);
        }else{
            ShowKillMarkOverlay(attacker,kills[attacker]);
        }
        PrecacheSound(path,true);
        EmitSoundToClient(attacker,path,SOUND_FROM_PLAYER);
        CreateKillTimer(attacker);
    }else{
        //首次击杀
        kills[attacker]++;
        PrecacheSound("cf/kill.mp3",true);
        EmitSoundToClient(attacker,"cf/kill.mp3",SOUND_FROM_PLAYER);
        ShowKillMarkOverlay(attacker,1);
        CreateKillTimer(attacker);
    }
    CreateKillTimer(attacker);
    return Plugin_Handled;
}
//击杀计时器用来重置击杀
public void CreateKillTimer(int attacker){
    if(killTimer[attacker]!=INVALID_HANDLE){
    delete(killTimer[attacker]);
    killTimer[attacker]=CreateTimer(3.0,ResetKillCooldown,attacker,TIMER_FLAG_NO_MAPCHANGE);
    }else{
    killTimer[attacker]=CreateTimer(3.0,ResetKillCooldown,attacker,TIMER_FLAG_NO_MAPCHANGE);
    }
}
//清除覆盖层图片
public void ClearOverlay(int client){
    //客户端需要这个解锁权限
    int iFlags = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", iFlags);
	ClientCommand(client, "r_screenoverlay 0");
}
//预载击杀图标
public void PrecacheKillMarks(){
    char tmp[64];
    PrecacheDecal("overlays/cf/headshot.vtf",true);
    PrecacheDecal("overlays/cf/headshot.vmt",true);
    PrecacheDecal("overlays/cf/boom.vtf",true);
    PrecacheDecal("overlays/cf/boom.vmt",true);
    for(int i=1;i<=6;i++){
        Format(tmp,sizeof(tmp),"overlays/cf/%dkill.vtf",i);
        PrecacheDecal(tmp,true);
        Format(tmp,sizeof(tmp),"overlays/cf/%dkill.vmt",i);
        PrecacheDecal(tmp,true);
    }
}
//显示击杀图标覆盖层
public void ShowKillMarkOverlay(int client,int type){
    PrecacheKillMarks();
    int iFlags = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", iFlags);
    switch(type){
        case (0):ClientCommand(client, "r_screenoverlay overlays/cf/headshot");
        case (1):ClientCommand(client, "r_screenoverlay overlays/cf/1kill");
        case (2):ClientCommand(client, "r_screenoverlay overlays/cf/2kill");
        case (3):ClientCommand(client, "r_screenoverlay overlays/cf/3kill");
        case (4):ClientCommand(client, "r_screenoverlay overlays/cf/4kill");
        case (5):ClientCommand(client, "r_screenoverlay overlays/cf/5kill");
        case (6):ClientCommand(client, "r_screenoverlay overlays/cf/6kill");
        case (7):ClientCommand(client, "r_screenoverlay overlays/cf/boom");
    }
}