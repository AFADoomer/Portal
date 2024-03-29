class NoPuff : Actor
{
	Default
	{
		+ALLOWTHRUFLAGS
		+MTHRUSPECIES
		+NOBLOCKMAP
		+NOGRAVITY
	}

	States
	{
		Spawn:
		XDeath:
		Crash:
		Melee:
			TNT1 A 2;
			Stop;
	}
}

class LaserHit : Actor
{
	SparkSpawner sparks;

	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+ALWAYSPUFF
		+INVISIBLE
		+FORCEDECAL
		+PUFFGETSOWNER
		DamageType "Laser";
		Decal "RailScorchLower";
		Radius 0;
		Height 0;
	}

	States
	{
		XDeath:
		Melee:
		Crash:
		Spawn:
			UNKN A 0;
			UNKN A 2;
			Stop;
	}

	override void PostBeginPlay()
	{
		A_StartSound("laser/hit", CHAN_AUTO, 0, 0.05, ATTN_STATIC);

		if (level.time % Random(3, 7) == 0 && self)
		{
			sparks = SparkSpawner(Spawn("SparkSpawner", pos));

			if (sparks)
			{
				sparks.A_SetTics(1);
				sparks.angle = angle;
				sparks.pitch = pitch;
				sparks.silent = true;
			}
		}

		Super.PostBeginPlay();
	}
}