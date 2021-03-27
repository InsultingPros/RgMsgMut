class RgMsgMut extends Mutator
	config(RgMsgMut);

struct ZedStruct {
	var KFMonster Zed;
	var float timeDamaged;
};

struct MsgStruct {
	var KFMonster Raged;
	var string Msg;
	var float timeShow;
};

const MSG_Delay = 0.05;

var array<ZedStruct> LevelZeds;
var array<MsgStruct> Messages;
var string TCode, NCode, ZCode, WCode;
var bool bTimerSet;

var config string MsgText;
var config bool bScrakeMsg, bPoundMsg;
var config color TColour, NColour, ZColour, WColour;

static function FillPlayInfo(PlayInfo PlayInfo) {
	Super.FillPlayInfo(PlayInfo);
	
	PlayInfo.AddSetting("Rage Messages", "bPoundMsg", "Fleshpounds", 0, 0, "Check");
	PlayInfo.AddSetting("Rage Messages", "bScrakeMsg", "Scrakes", 0, 0, "Check");
	PlayInfo.AddSetting("Rage Messages", "MsgText", "Message", 255, 1, "Text", "64");
}

static event string GetDescriptionText(string Property) {
	switch (Property) {
		case "bPoundMsg":
			return "Show a message when a fleshpound is raged.";
		case "bScrakeMsg":
			return "Show a message when a scrake is raged.";
		case "MsgText":
			return "Expressions: %n - player's name, %w - player's weapon, %z - scrake or fleshpound.";
		default:
			return Super.GetDescriptionText(Property);
	}
}

function PostBeginPlay() {
	local RgMsgRules GR;
	
	Super.PostBeginPlay();
	
	GR = Spawn(class'RgMsgRules');
	GR.Mut = Self;
	
	if (Level.Game.GameRulesModifiers == None)
		Level.Game.GameRulesModifiers = GR;
	else
		Level.Game.GameRulesModifiers.AddGameRules(GR);
	
	TCode = class'Engine.GameInfo'.static.MakeColorCode(TColour);
	NCode = class'Engine.GameInfo'.static.MakeColorCode(NColour);
	ZCode = class'Engine.GameInfo'.static.MakeColorCode(ZColour);
	WCode = class'Engine.GameInfo'.static.MakeColorCode(WColour);
}


function bool CheckReplacement(Actor Other, out byte bSuperRelevant) {
	local ZedStruct NewZed;
	
	if (ZombieScrake(Other) != None || ZombieFleshpound(Other) != None) {
		NewZed.Zed = KFMonster(Other);
		LevelZeds[LevelZeds.length] = NewZed;
	}
		
	return true;
}

function ScoreKill(Pawn Killed) {
	local int i;
	
	if (ZombieScrake(Killed) != None || ZombieFleshpound(Killed) != None) {
		for (i = 0; i < LevelZeds.length; i++) {
			if (LevelZeds[i].Zed == Killed) {
				LevelZeds.Remove(i, 1);
				break;
			}
		}
	}
}

function bool ScrakeIsRaging(float aDiff, int aHealth, int aHealthMax, optional int aDamage) {
	return aDiff >= 5.0 && float(aHealth - aDamage) / aHealthMax < 0.75 || float(aHealth - aDamage) / aHealthMax < 0.5;
}

function bool IsStunned(KFMonster aMonster) {
	local Name AnimName;
	local float animFrame, animRate;
	
	aMonster.GetAnimParams(0, AnimName, animFrame, animRate);
	if (AnimName == 'KnockDown')
		return true;
	else
		return false;
}

function bool ImminentRage(KFMonster aMonster, int aDamage) {
	local int twoSecondDamageTotal;
	
	if (ZombieScrake(aMonster) != None) {
		if (!bScrakeMsg || aMonster.health <= aDamage || aMonster.bDecapitated || ScrakeIsRaging(Level.Game.gameDifficulty, aMonster.health, aMonster.healthMax))
			return false;
		
		return !IsStunned(aMonster) && ScrakeIsRaging(Level.Game.gameDifficulty, aMonster.health, aMonster.healthMax, aDamage);
	}
	else if (ZombieFleshpound(aMonster) != None) {
		if (!bPoundMsg || aMonster.health <= aDamage || aMonster.bDecapitated || aMonster.bZapped || aMonster.bCrispified && aMonster.bBurnified || ZombieFleshpound(aMonster).bChargingPlayer || aMonster.IsInState('BeginRaging') || aMonster.IsInState('StartCharging') || aMonster.IsInState('RageCharging') || aMonster.IsInState('ChargeToMarker'))
			return false;
		
		twoSecondDamageTotal = ZombieFleshpound(aMonster).twoSecondDamageTotal + aDamage;
		if (twoSecondDamageTotal > ZombieFleshpound(aMonster).rageDamageThreshold)
			return true;
	}
	
	return false;
}

function bool DelayExceeded(Pawn Injured) {
	local bool bExceeded;
	local int i;
	
	if (ZombieFleshPound(Injured) == None)
		return false;
	
	for (i = 0; i < LevelZeds.length; i++) {
		if (LevelZeds[i].Zed == Injured) {
			if (Level.timeSeconds - LevelZeds[i].timeDamaged > 0.07)
				bExceeded = true;
			
			LevelZeds[i].timeDamaged = Level.timeSeconds;
			break;
		}
	}
	
	return bExceeded;
}

function string GetNameOf(Pawn Other) {
	local string OtherName;

	if (Other == None)
		return "Someone";
	
	if (Other.PlayerReplicationInfo != None)
		return Other.PlayerReplicationInfo.PlayerName;
	
	if (Other.MenuName != "")
		OtherName = Other.MenuName;
	else
		OtherName = string(Other.Class.Name);
	
	return OtherName;
}

function string GetItemNameOf(class<WeaponDamageType> aDamageType) {
	if (aDamageType == None)
		return "something";
	else if (aDamageType == class'KFMod.DamTypeDualies')
		return class'KFMod.Single'.default.ItemName;
	else if (aDamageType == class'KFMod.DamTypeBurned')
		return "fire";
	else if (aDamageType == class'KFMod.DamTypeMedicNade')
		return "Medic Nade";
	else if (aDamageType == class'KFMod.DamTypeDBShotgun')
		return "Hunting Shotgun";
	else if (aDamageType == class'KFMod.DamTypeScythe')
		return "Scythe";
	
	return aDamageType.default.WeaponClass.default.ItemName;
}

function string GetRageMessage(Pawn Injured, Pawn InstigatedBy, class<WeaponDamageType> DmgType) {
	local string Msg;
	
	Msg = TCode;
	Msg $= Repl(MsgText, "%n", NCode $ GetNameOf(InstigatedBy) $ TCode);
	Msg = Repl(Msg, "%z", ZCode $ GetNameOf(Injured) $ TCode);
	Msg = Repl(Msg, "%w", WCode $ GetItemNameOf(DmgType) $ TCode);
	
	return Msg;
}

function DelayedRageMessage(Pawn Injured, Pawn InstigatedBy, class<WeaponDamageType> DmgType) {
	Messages.Insert(0, 1);
	Messages[0].Raged = KFMonster(Injured);
	Messages[0].Msg = GetRageMessage(Injured, InstigatedBy, DmgType);
	Messages[0].timeShow = Level.timeSeconds + MSG_Delay;
	if (!bTimerSet) {
		bTimerSet = true;
		SetTimer(MSG_Delay, false);
	}
}

function BroadcastDelayedMessages() {
	local int i;
	
	for (i = Messages.length - 1; i >= 0; i--) {
		if (Messages[i].timeShow > Level.timeSeconds) {
			bTimerSet = true;
			SetTimer(Messages[i].timeShow - Level.timeSeconds, false);
			break;
		}
		
		if (Messages[i].Raged != None && !Messages[i].Raged.bDecapitated && !IsStunned(Messages[i].Raged))
			Level.Game.Broadcast(Level.Game, Messages[i].Msg);
		
		Messages.Remove(i, 1);
	}
}

function Timer() {
	bTimerSet = false;
	BroadcastDelayedMessages();
}

defaultproperties
{
     MsgText="%n has raged %z with %w!"
     bScrakeMsg=True
     bPoundMsg=True
     TColour=(B=255,G=255,R=255,A=255)
     NColour=(B=255,G=120,R=120,A=255)
     ZColour=(B=120,G=120,R=255,A=255)
     WColour=(B=120,G=255,R=120,A=255)
     GroupName="KFRgMsgMut"
     FriendlyName="Rage Messages"
     Description="Shows a message when a scrake or a fleshpound is raged."
}
