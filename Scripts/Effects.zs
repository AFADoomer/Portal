class SingleSpark : Actor
{
	Actor colorsetter;
	double fadeamt;
	int rollamt;
	bool fade;

	Property Fade:fade;

	Default
	{
		PROJECTILE;
		+NOBLOCKMAP
		+BRIGHT
		+NOTELEPORT
		-NOGRAVITY
		+ROLLSPRITE
		+FORCEXYBILLBOARD
		+DONTSPLASH
		Height 0;
		Radius 0;
		Speed 1;
		Mass 1;
		Scale 0.02;
		Gravity 0.1;
		RenderStyle "AddStencil";
		StencilColor "White";
		BounceType "Hexen";
		SingleSpark.Fade True;
	}

	States
	{
		Spawn:
			FLAS H 1;
			Loop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		if (colorsetter) { SetShade(colorsetter.fillcolor); }
		else { SetShade(RandomPick(color(250, 234, 146), color(224, 207, 99), color(189, 175, 76), color(253, 237, 152), color(255, 200, 100))); }

		fadeamt = 0.025;

		Scale.X = Scale.X * (FRandom(0.7, 1.3));
		Scale.Y = Scale.Y * (FRandom(0.7, 1.3));
		rollamt = Random(-15, 15);

		if (!SingleSpark(master) && Random() < 32)
		{
			let mo = A_SpawnProjectile(GetClassName(), -1, 0, Random(0, 359), CMF_AIMDIRECTION, 0);
			mo.master = master;
		}

		A_Face(master, 360, 180);
	}

	override void Tick()
	{
		Super.Tick();

		if (IsFrozen()) { return; }

		if (pos.z > floorz + 1 || vel.length() > 0.1) { roll += rollamt; }
		else { vel *= 0; bNoInteraction = true; }

		if (fade) { A_FadeOut(fadeamt); }
		if (waterlevel) { fadeamt *= 2; }
	}
}

class SparkSpawner : Actor
{
	Class<SingleSpark> sparkactor;
	bool silent, colorize;

	Property SparkActor:sparkactor;
	Property Colorize:colorize;
	Property silent:silent;

	Default
	{
		//$Category Portal/Effects
		//$Title Spark Spawner
		+INVISIBLE
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+CLIENTSIDEONLY
		Height 4;
		Radius 0;
		SparkSpawner.SparkActor "SingleSpark";
	}

	States
	{
		Spawn:
			UNKN A 10 Light("SparkLight");
			Stop;
	}

	override void PostBeginPlay()
	{
		bDormant = SpawnFlags & MTF_DORMANT;

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		if (IsFrozen() || bDormant) { return; }

		Super.Tick();

		if (!silent) { A_StartSound("world/spark", CHAN_AUTO, 0, FRandom(0.1, 0.2)); }

		int sparkangle;

		if (pitch > 0 && pitch % 180 == 0) {
			sparkangle = Random(0, 360);
		} else {
			sparkangle = Random(-45, 45);
		}
					
		let mo = A_SpawnProjectile(sparkactor, -1, 0, sparkangle, CMF_AIMDIRECTION, 270 - pitch + FRandom(-45, 45));
		if (colorize) { SingleSpark(mo).colorsetter = self; }
	}

	override void Activate(Actor activator) { bDormant = false; Super.Activate(activator); }
	override void Deactivate(Actor activator) { bDormant = true; Super.Deactivate(activator); }
}

class ConfettiSpawner : SparkSpawner
{
	int user_duration;

	Default
	{
		//$Title Confetti Spawner
		SparkSpawner.SparkActor "Confetti";
		SparkSpawner.Colorize True;
		SparkSpawner.Silent True;
	}

	States
	{
		Spawn:
			UNKN A 0;
			UNKN A 35 { A_SetTics(user_duration > 0 ? user_duration : 35); }
			Stop;
	}

	override void PostBeginPlay()
	{
		if (!pitch) { pitch = 180; }

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		SetShade(RandomPick(color(63, 72, 204), color(255, 0, 255), color(0, 0, 160), color(128, 128, 255), color(255, 0, 128)));

		Super.Tick();
	}
}

class Confetti : SingleSpark
{
	Default
	{
		-BRIGHT
		+FLATSPRITE
		Scale 0.125;
		BounceFactor 0.05;
		Renderstyle "Stencil";
		SingleSpark.Fade False;
		Gravity 0.05;
	}

	States
	{
		Spawn:
			CONF A 1;
			Loop;
	}

	override void PostBeginPlay()
	{
		Scale *= FRandom(0.7, 1.1);

		Super.PostBeginPlay();
	}
}

class SmokePuff : Actor
{
	Default
	{
		+FORCEXYBILLBOARD
		+NOINTERACTION
		+WINDTHRUST
		RenderStyle "Translucent";
		Alpha 0.1;
		Scale 0.04;
		VSpeed 1;
		Radius 0;
		Height 0;
	}

	States
	{
		Spawn:
			SMOK # 0;
			SMOK # 1;
		FadeIn:
			SMOK # 0 {
				alpha += 0.04;

				if (alpha < 0.7) { SetStateLabel("FadeIn"); }
			}
		FadeOut:
			SMOK # 3;
			SMOK # 0 {
				alpha -= 0.025;
				Scale *= 1.1;

				if (alpha > 0.1) { SetStateLabel("FadeOut"); }
			}
			Stop;
	}

	override void PostBeginPlay()
	{
		scale.x *= FRandom(0.35, 0.7);
		scale.y *= FRandom(0.35, 0.7);

		frame = Random(0, 2);
	}
}

class ExplosionFlare : Actor
{
	Default
	{
		+FORCEXYBILLBOARD
		+NOINTERACTION
		+NOGRAVITY
		RenderStyle "Add";
	}

	States
	{
		Spawn:
			EXPL # 5 Bright;
		FadeOut:
			EXPL # 1 Bright;
			EXPL # 0 {
				A_RemoveLight("ExplosionLight");

				alpha = max(0, alpha - FRandom(0.1, 0.15));
				A_AttachLight("ExplosionLight", DynamicLight.PointLight, 0xFFBB00, int(128 * alpha * scale.x), int(192 * alpha * scale.x), DynamicLight.LF_ATTENUATE);

				if (alpha > 0) { SetStateLabel("FadeOut"); }
			}
			Stop;
	}

	override void PostBeginPlay()
	{
		scale.x *= FRandom(0.5, 0.8);
		scale.y *= FRandom(0.5, 0.8);

		A_AttachLight("ExplosionLight", DynamicLight.PointLight, 0xFFBB00, int(128 * scale.x), int(192 * scale.x), DynamicLight.LF_ATTENUATE);
		A_StartSound("world/flareup", CHAN_AUTO, 0, 1.0 * scale.x, ATTN_IDLE);

		frame = Random(0, 3);
	}
}

class ExplosionSmoke : Actor
{
	Default
	{
		+FORCEXYBILLBOARD
		+NOINTERACTION
		RenderStyle "Translucent";
		Alpha 0.8;
		VSpeed 1;
	}

	States
	{
		Spawn:
			TSMK A 0;
		FadeOut:
			TSMK A 1;
			TSMK A 0 {
				scale.x += FRandom(0.005, 0.015);
				scale.y += FRandom(0.005, 0.015);

				alpha = max(0, alpha - FRandom(0.003, 0.006));

				if (alpha > 0) { SetStateLabel("FadeOut"); }
			}
			Stop;
	}
}

class ExplosionSmokeGenerator : Actor
{
	Default
	{
		+NOINTERACTION
		+NOGRAVITY
		ReactionTime 8;
	}

	States
	{
		Spawn:
			TNT1 A 15;
		SpawnLoop:
			TNT1 A 1 {
				A_SpawnItemEx("ExplosionSmoke", 0, 0, 0, 0.0, FRandom(0.0, 2.5) * Scale.x, FRandom(-2.0, 2.0) * Scale.y, Random(0, 359), SXF_CLIENTSIDE | SXF_TRANSFERSCALE, 30);

				if (reactiontime-- > 0) { SetStateLabel("SpawnLoop"); }
			}
			Stop;
	}
}

class ExplosionSpark : Actor
{
	Default
	{
		+FORCEXYBILLBOARD
		+NOINTERACTION
		+BRIGHT
		RenderStyle "Add";
		Alpha 1.0;
		VSpeed 1;
	}

	States
	{
		Spawn:
			PAO1 A 5;
		FadeOut:
			PAO1 A 1;
			PAO1 A 0 {
				A_RemoveLight("SparkLight");

				vel.x *= FRandom(0.98, 0.99);
				vel.y *= FRandom(0.98, 0.99);
				vel.z -= FRandom(0.2, 0.5);

				scale.x -= 0.002;
				scale.y = scale.x;

				alpha = max(0, alpha - 0.01);

				if (alpha > 0) { SetStateLabel("FadeOut"); }
			}
			Stop;
	}

	override void PostBeginPlay()
	{
		scale *= FRandom(0.07, 0.1);
		A_AttachLight("SparkLight", DynamicLight.PointLight, 0xCC7700, int(48 * scale.x), 0, DynamicLight.LF_ATTENUATE);
	}
}

class ExplosionSparkGenerator : Actor
{
	Default
	{
		+NOINTERACTION
		+NOGRAVITY
		ReactionTime 24;
	}

	States
	{
		Spawn:
			TNT1 A 0;
			TNT1 A 1 {
				A_SpawnItemEx("ExplosionSpark", 0, 0, 0, 0.0, FRandom(0.0, 13.5) * Scale.X, FRandom(-1.0, 9.5) * Scale.y, Random(0, 359), SXF_CLIENTSIDE | SXF_TRANSFERSCALE, 60);
				if (reactiontime-- > 0) { SetStateLabel("Spawn"); }
			}
			Stop;
	}
}

class Explosion : SwitchableDecoration
{
	Default
	{
		//$Category Portal/Special Effects
		//$Title Explosion Effect
		+NOINTERACTION
		+NOGRAVITY
	}

	States
	{
		Spawn:
			TNT1 A 1;
		Active:
		Inactive:
			TNT1 A 350;
			Wait;
	}

	override void Activate(Actor activator)
	{
		A_StartSound("world/explosion", CHAN_AUTO, 0, 0.75 * scale.x, ATTN_IDLE);
		A_Quake(int(4 * scale.x), int(10 * scale.x), 0, int(512 * scale.x), "");
		A_Explode(100, int(192 * scale.x));

		Actor flare = Spawn("ExplosionFlare", pos);
		if (flare) { flare.master = master; flare.scale = scale; }

		Actor smoke = Spawn("ExplosionSmokeGenerator", pos);
		if (smoke) { smoke.master = master; smoke.scale = scale; }

		Actor sparks = Spawn("ExplosionSparkGenerator", pos);
		if (sparks) { sparks.master = master; sparks.scale = scale; }

		Actor sphere = Spawn("ExplosionSphere", pos);
		if (sphere) { sphere.master = master; sphere.scale = scale; }

		Super.Activate(activator);
	}

	override void PostBeginPlay()
	{
		bDormant = SpawnFlags & MTF_DORMANT;

		if (master)
		{
			scale.x = max(master.radius * 2, master.height) / 32.0;
			scale.y = scale.x;

			SetOrigin(master.pos + (0, 0, master.height / 2), false);
		}

		if (!bDormant) { Activate(self); }
	}

	override void Tick()
	{
		if (IsFrozen()) { return; }

		Super.Tick();
	}
}

class Debris : Actor
{
	double rollamt;
	double pitchamt;
	double scaleamt;
	int loopcount;

	Default
	{
		PROJECTILE;
		-NOGRAVITY
		+NOBLOCKMAP
		+MOVEWITHSECTOR
		+USEBOUNCESTATE
		+THRUACTORS;
		Height 2;
		Radius 1;
		Speed 10;
		Mass 10;
		BounceType "Doom";
		BounceFactor 0.35;
		BounceSound "debris/bounce";
		WallBounceSound "debris/bounce";
	}
	States
	{
		Spawn:
			UNKN A 0;
		Bounce:
			UNKN # 0 {
				rollamt = FRandom(-5.0, 5.0);
				pitchamt = FRandom(-5.0, 5.0);
				scaleamt = Scale.Y / 100;
			}
		SpawnLoop:
			UNKN # 1 {
				roll += rollamt;
				pitch += pitchamt;
				if (!vel.length()) { SetStateLabel("Death"); }
				if (loopcount >= 175) { SetStateLabel("FadeOut"); }
				if (GetGravity() <= 0.75) { loopcount++; }
			}
			Loop;
		Death:
			UNKN # -1;
			Stop;
		FadeOut:
			UNKN # 1 {
				if (pos.z >= floorz + height / 2) {
					if (GetGravity()) {
						SetOrigin((pos.x, pos.y, height / 2), true);
						Gravity = 0;
					}
				}
				else { 
					roll += rollamt;
					pitch += pitchamt;
				}
				A_FadeOut(0.01);
				Scale.Y -= scaleamt;
			}
			Loop;
	}

	override void PostBeginPlay()
	{
		frame = Random(0, 2);

		if (master) { Scale = Default.Scale * master.Radius / Random(8, 12); }

		Scale *= FRandom(0.1, 0.5);

		if (scale.x >= 3) { BounceSound = "debris/bounce/large"; WallBounceSound = "debris/bounce/large"; }
		else if (scale.x >= 2) { BounceSound = "debris/bounce/medium"; WallBounceSound = "debris/bounce/medium"; }

		Speed = Max(GetGravity() * Speed + Scale.X, 1);
	}

	override void Tick()
	{
		if (pos.z == floorz && floorpic == skyflatnum)
		{
			ClearBounce();
			BounceSound = "";
			WallBounceSound = "";
			scale *= 0.9;

			if (Scale.X < 0.05) { Destroy(); return; }
		} 

		Super.Tick();
	}
}

class DebrisSpawner : Actor
{
	int debriscount;
	int maxcount;

	Default
	{
		+INVISIBLE
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+CLIENTSIDEONLY
		Height 2;
		Radius 1;
	}

	States
	{
		Spawn:
			UNKN A 0;
		SpawnDebris:
			UNKN A 1 {
				while (debriscount < maxcount)
				{
					int zoffset = master ? Random(0, int(master.height)) : 0;

					let mo = A_SpawnProjectile("Debris", -1, zoffset, Random(0, 360), CMF_AIMDIRECTION, Random(-45, 45));
					mo.scale = FRandom(scale.x / 5, scale.x) * (1.0, 1.0);
					mo.vel *= scale.x;

					if (master) { mo.master = master; }

					debriscount++;
				}
			}
			Stop;
	}

	override void PostBeginPlay()
	{
		if (master)
		{
			SetOrigin(master.pos + (0, 0, master.height / 2), false);
			maxcount = master.mass / 25;
			scale = master.scale;
		}
		else { maxcount = 4; }
	}
}

class ExplosionSphere : Actor
{
	Default
	{
		+BRIGHT
		+NOGRAVITY
		+NOINTERACTION
		RenderStyle "Add";
		Alpha 0.04;
	}

	States
	{
		Spawn:
			UNKN A 1;
			Loop;
	}

	override void PostBeginPlay()
	{
		if (master)
		{
			SetXYZ(master.pos + (0, 0, master.height / 2));
		}

		A_AttachLight("ExplosionLight", DynamicLight.PointLight, 0xE6E64D, int(48 * alpha * scale.x), 0, DynamicLight.LF_ATTENUATE);
	}

	override void Tick()
	{
		if (IsFrozen()) { return; }
		A_RemoveLight("ExplosionLight");

		alpha = max(0, alpha - 0.003);
		scale *= 1.5;

		A_AttachLight("ExplosionLight", DynamicLight.PointLight, 0xE6E64D, int(48 * alpha * scale.x), 0, DynamicLight.LF_ATTENUATE);

		Super.Tick();

		if (alpha <= 0) { Destroy(); }
	}
}
