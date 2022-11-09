#include <sdktools_engine>
#include <sdktools_functions>
#include <sdktools_trace>
#include <sdktools_tempents>
#include <sdktools_sound>
#include <sdktools_tempents_stocks>

ConVar
	cvHookSpeed,		//Скорость хука
	cvEnable;	
	
int
	iRemainingDuration[MAXPLAYERS+1],		//Оставшаяся продолжительность
	iAllowedDuration[MAXPLAYERS+1][3],	//Разрешенная продолжительность
	iLaser,
	iCountHook[MAXPLAYERS+1];	//Количество хуков за N времени
	
float
	fHookEndloc[MAXPLAYERS+1][3],	//Координаты куда смотрит клиент
	fAllowedRange[MAXPLAYERS+1][3],	//Допустимый диапазон	hook 0; grab 1; rope 2
	fGravity[MAXPLAYERS+1];		//Изначальная гравити игрока

char
	sSound[256],
	sVmt[256];

public Plugin myinfo = 
{
	name = "[Any] Hook Lite",
	author = "Nek.'a 2x2 | ggwp.site ",
	description = "Паутинка с гибкими настройками",
	version = "1.0.2",
	url = "https://ggwp.site/"
};

public void OnPluginStart()
{
	if(GetEngineVersion() == Engine_CSS)
	{
		sVmt = "sprites/laser.vmt";
		sSound = "weapons/crossbow/fire1.wav";
	}
	else if(GetEngineVersion() == Engine_CSGO)
	{
		sVmt = "sprites/laserbeam.vmt";
		sSound = "weapons/taser/aser_hit.wav";
	}
	
	cvEnable = CreateConVar("sm_hook_lite_enable", "0", "Включен ли хук для всех, -1 плагин выключен, 0 отключен (включается в нужный момент), 1 включен для всех");
	cvHookSpeed = CreateConVar("sm_hook_lite_speed", "5.0", "Скорость игрока с помощью хука");
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", OnEnd);
	
	RegConsoleCmd("+hook", HookCmd);
	
	AutoExecConfig(true, "hook_lite");
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i)) iCountHook[i] = 0;
	
	if(cvEnable.IntValue == -1)
		return;
		
	if(cvEnable.IntValue == 3)
	{
		cvEnable.IntValue = 0;
		return;
	}
	
	int iPlayerCount, i;
	
	for(i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		iPlayerCount++;
	
	if(iPlayerCount < 2)
		cvEnable.IntValue = 1;
	
}

public void OnEnd(Handle event, char[] name, bool dontBroadcast)
{
	if(cvEnable.IntValue == -1)
		return;
	
	if(!cvEnable.IntValue)
	{
		PrintToChatAll("[Hook Lite] HOOK Активин для всех !");
		cvEnable.IntValue = 3;
	}
}

public void OnMapStart()
{
	iLaser = PrecacheModel(sVmt);
	PrecacheSound(sSound, true);
}

public Action HookCmd(int client, int argc)
{
	if(cvEnable.IntValue == -1)
		return Plugin_Continue;
		
	if(!cvEnable.IntValue)
	{
		PrintToChat(client, "[Hook Lite] HOOK сейчас не доступен")
		return Plugin_Continue;
	}
		
	if (IsValidClient(client) && IsClientInGame(client) && IsPlayerAlive(client))
		Action_Hook(client);
	return Plugin_Handled;
}

int Action_Hook(int client)
{
	iCountHook[client]++;
	float fClientloc[3], fClientang[3], fPos[3];
	GetClientEyePosition(client, fClientloc);	// Определите положение глаз игрока
	GetClientEyeAngles(client, fClientang);		// Определите угол, под которым смотрит игрок
	GetClientAbsOrigin(client, fPos)
	
	// Создайте луч, указывающий, куда смотрит игрок
	TR_TraceRayFilter(fClientloc, fClientang, MASK_SOLID,RayType_Infinite, TraceRayTryToHit);
	TR_GetEndPosition(fHookEndloc[client]);	// Получить конечную координату xyz того места, куда смотрит игрок
	
	float fLimit = fAllowedRange[client][1];	//grap
	float fDistance = GetVectorDistance(fClientloc, fHookEndloc[client]);
	if (fLimit == 0.0 || fDistance <= fLimit)
	{
		if (iRemainingDuration[client] <= 0)
			iRemainingDuration[client] = iAllowedDuration[client][0];

		fGravity[client] = GetEntPropFloat(client, Prop_Data, "m_flGravity"); // Сохранить старую гравитацию клиента
		SetEntPropFloat(client, Prop_Data, "m_flGravity", 0.0);		//гравитацию на 0, чтобы клиент плавал по прямой линии
		Hook_Push(client);
		EmitAmbientSound(sSound, fPos);
	}
}

int Hook_Push(int client)
{
	float fClientloc[3], fVelocity[3];
	GetClientAbsOrigin(client, fClientloc);	//Позиция игрока
	fClientloc[2] += 30.0;

	int iColor[4];
	
	if(iCountHook[client] < 5)
	{
		iColor[0] = 138;
		iColor[1] = 54;
		iColor[2] = 46;
		iColor[3] = 255;
		TE_SetupBeamPoints(fClientloc, fHookEndloc[client], iLaser, 0, 0, 66, 0.2, 0.5, 1.5, 0, 3.0, iColor, 0);
	}
	else
	{
		iColor[0] = GetRandomInt(0, 255);
		iColor[1] = GetRandomInt(0, 255);
		iColor[2] = GetRandomInt(0, 255);
		iColor[3] = 255;
		float fCvars[4];
		fCvars[0] = GetRandomFloat(0.7, 5.5);	//Начальная ширина
		fCvars[1] = GetRandomFloat(1.5, 9.5);	//Конечная ширина
		if(fCvars[0] >= fCvars[1])
			fCvars[1] = fCvars[0] - 0.1;
		fCvars[1] = GetRandomFloat(1.0, 3.5);	//Сила амплитуды
		//TE_SetupBeamPoints(Начало, Концовка, Модель 1, Модель 2, Начальный кадр, Частота кадров, Жзнь, Ширина, Ширина конец, 0, Аплитуда, iColor, 0);
		TE_SetupBeamPoints(fClientloc, fHookEndloc[client], iLaser, 0, 0, 100, 0.2, fCvars[0], fCvars[1], 0, 3.0, iColor, 0);
	}
	
	TE_SendToAll();
	GetForwardPushVec(fClientloc, fHookEndloc[client], fVelocity);	// Get how hard and where to push the client
	TeleportEntity(client,NULL_VECTOR,NULL_VECTOR, fVelocity);	// Push the client
	float fDistance=GetVectorDistance(fClientloc, fHookEndloc[client]);
	if (fDistance < 30.0)
	{
		SetEntityMoveType(client, MOVETYPE_NONE);	// https://sm.alliedmods.net/new-api/entity_prop_stocks/SetEntityMoveType

		float gravity = fGravity[client];	// Set gravity back to saved value (or normal)
		SetEntPropFloat(client, Prop_Data, "m_flGravity", (gravity != 0.0) ? gravity : 1.0);
	}
}

void GetForwardPushVec(const float start[3], const float end[3], float output[3])
{
	CreateVectorFromPoints(start,end,output);
	NormalizeVector(output,output);
	output[0] *= cvHookSpeed.FloatValue * 140.0;
	output[1] *= 5.0 * 140.0;
	output[2] *= 5.0 * 140.0;
}

float CreateVectorFromPoints(const float vec1[3], const float vec2[3], float output[3])
{
	output[0]=vec2[0]-vec1[0];
	output[1]=vec2[1]-vec1[1];
	output[2]=vec2[2]-vec1[2];
}

bool IsValidClient(int client)
{
	if(0 < client && client <= MaxClients)
		return true;
	return false;
}

public bool TraceRayTryToHit(int entity, int mask)
{
	if(entity > 0 && entity <= MaxClients)	//Проверьте, попал ли луч в игрока, и скажите ему, чтобы он продолжал отслеживать, если это произошло
		return false;
	return true;
}