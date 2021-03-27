class RgMsgRules extends GameRules;

var RgMsgMut Mut;

function ScoreKill(Controller Killer, Controller Killed) {
	if (Killed != None)
		Mut.ScoreKill(Killed.Pawn);

	Super.ScoreKill(Killer, Killed);
}

function int NetDamage(int originalDamage, int damage, Pawn Injured, Pawn InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType) {
	local bool bBileTimer;

	if (NextGameRules != None)
		damage = NextGameRules.NetDamage(originalDamage, damage, Injured, InstigatedBy, HitLocation, Momentum, DamageType);
	
	if (damage > 0 && (ZombieScrake(Injured) != None || ZombieFleshpound(Injured) != None)) {
		if (ZombieFleshpound(Injured) != None && class<DamTypeBlowerThrower>(DamageType) != None && !(KFHumanPawn(InstigatedBy) != None && BlowerThrower(KFHumanPawn(InstigatedBy).Weapon) != None && KFHumanPawn(InstigatedBy).Weapon.GetFireMode(0).IsFiring() && KFMonster(Injured).bileCount == 7) && Mut.DelayExceeded(Injured))
			bBileTimer = Abs(KFMonster(Injured).nextBileTime - KFMonster(Injured).bileFrequency - Level.timeSeconds) < 0.01;
			
		if (!bBileTimer && Mut.ImminentRage(KFMonster(Injured), damage))
			Mut.DelayedRageMessage(Injured, InstigatedBy, class<WeaponDamageType>(DamageType));
	}
	
	return damage;
}

defaultproperties
{
}
