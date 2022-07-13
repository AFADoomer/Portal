class Pellet : Actor
{
	Default
	{
		Projectile;		
		+BOUNCEONACTORS
		+DONTBOUNCEONSHOOTABLES
		+FORCEXYBILLBOARD
		Radius 10;
		Height 20;
		Speed 2.0;
		Damage 100;
		BounceType "Hexen";
		BounceCount 5;
		BounceFactor 1.0;
		RenderStyle "Add";
		Scale 0.4;
		Alpha 0.35;
		SeeSound "weapons/plasmaf";
		BounceSound "vile/firestrt";
		DeathSound "weapons/plasmax";
		Obituary "%o was killed by an energy pellet.";
	}

	States
	{
		Spawn:
			PLSS A 6;
			Loop;
		Death:
			PLSE ABCDE 4 Bright A_Explode(damage, 32);
			Stop;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER);
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		Actor shell;

		While (!shell) { shell = Spawn("PelletShell", pos); }
		shell.master = self;
	}
}

class PelletShell : Actor
{
	Actor light, flare;

	Default
	{
		+NOGRAVITY;
		+NOINTERACTION;
		Radius 0;
		Height 0;
		RenderStyle "Add";
		Alpha 0.4;
		Scale 0.8;
	}
	States
	{
		Spawn:
			UNKN A 1;
			Loop;
		Explode:
			UNKN A 35;
			Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		while (!AlphaLight(light)) { light = Spawn("AlphaLight", pos); }
		light.master = master;
		AlphaLight(light).maxradius = 16.0;
		AlphaLight(light).clr = Color(0, 191, 255);
		light.alpha = 1.0;
		AlphaLight(light).bAttenuate = true;

		while (!flare) { flare = Spawn("Flare", pos); }
		flare.master = self;
	}

	override void Tick()
	{
		Super.Tick();

		if (master)
		{
			SetXYZ(master.pos);

			if (light && AlphaLight(light)) { AlphaLight(light).maxradius = 16.0 + 8 * sin(level.time * 4); }

			if (InStateSequence(master.CurState, master.FindState("Death")))
			{
				master = null;
				AlphaLight(light).maxradius = 32.0;
				SetStateLabel("Explode");
			}
		}
		else
		{
			Scale *= 1.2;
			A_FadeOut(0.05);
			if (light)
			{
				light.alpha = max(light.alpha - 0.1, 0);
				if (light.alpha <= 0) { light.Destroy(); }
			}
		}
	}

	override void OnDestroy()
	{
		if (light) { light.Destroy(); }
	}
}


class Flare : Actor
{
	Actor light;

	Default
	{
		+NOGRAVITY
		+NOINTERACTION
		+FORCEXYBILLBOARD
		+INTERPOLATEANGLES
		Radius 0;
		Height 0;
		RenderStyle "Add";
		Alpha 0.4;
		Scale 0.35;
	}
	States
	{
		Spawn:
			FLAS H 1;
			Loop;
	}

	override void Tick()
	{
		Super.Tick();

		if (master)
		{
/*
			SetXYZ(master.pos);

			if (players[consoleplayer].mo)
			{
				double amt = 1.0 - abs(pos.z - players[consoleplayer].mo.pos.z) / 128;

				scale.y = clamp(amt * Default.scale.y, 0.05, Default.scale.y);
				alpha = clamp(amt * Default.alpha, 0.1, Default.alpha);
			}
*/
		}
		else
		{
			Destroy();
		}
	}
}

class LaserBeam : Actor
{
	color lasercolor;

	Property LaserColor:lasercolor;

	Default
	{
		+NOGRAVITY
		+NOINTERACTION
		+NOBLOCKMAP
		+BRIGHT
		+INTERPOLATEANGLES
		Radius 0;
		Height 0;
		RenderStyle "Add";
		RenderRadius 2048.0;
		LaserBeam.LaserColor 0xFF0000; // Does not affect graphic!  Used for Laser Cube glows.
	}

	States
	{
		Spawn:
			TNT1 A 0;
			UNKN A -1;
			Stop;
	}

	override void Tick()
	{
		if (!master) { Destroy(); }

		Super.Tick();
	}
}

class LaserBeamBlue : LaserBeam
{
	Default
	{
		Scale 2.0;
		LaserBeam.LaserColor 0x0007FF;
	}
}

class LaserBeamSight : LaserBeam
{
	Default
	{
		Alpha 0.25;
		Scale 0.25;
	}
}

class LaserLight : Actor
{
	Default
	{
		+INVISIBLE
		+NOINTERACTION
	}

	States
	{
		Spawn:
			UNKN A 0;
			UNKN A 1 Light("SmallRedLight");
			Stop;
	}
}

class LaserSpot : Actor
{
	LaserFindHitPointTracer hittracer;
	LaserBeam beam;
	Actor hitspot, flare, flare2;

	Default
	{
		+NOGRAVITY
		+NOINTERACTION
		+NOBLOCKMAP
		+INVISIBLE
		Species "Laser";
		Radius 0;
		Height 0;
	}

	States
	{
		Spawn:
		Inactive:
			UNKN A 1;
			Wait;
		Active:
			UNKN A 1 A_FireLaser();
			Loop;
	}

	override void PostBeginPlay()
	{
		hittracer = new("LaserFindHitPointTracer");

		if (SpawnFlags & MTF_DORMANT) { Deactivate(self); }
		else { Activate(self); }

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		if (IsFrozen() || bDormant) { return; }

		Super.Tick();

		if (master)
		{
			pitch = master.pitch;
			if (master is "PortalSpot" && Distance3D(master) > 32.0) { Destroy(); }
		}
	}

	void A_FireLaser(int damage = 3, sound snd = "")
	{
		if (snd != "" && level.time > 5)
		{
			A_StartSound(snd, CHAN_6, CHANF_NOSTOP | CHANF_LOOP, 0.0625, ATTN_STATIC);
		}

		double zoffset;
		if (master) { zoffset = pos.z - master.pos.z; }

		DoTrace(master, angle, 2048, pitch, 0, zoffset, hittracer);
		[beam, hitspot] = Utilities.DrawLaser(self, beam, hitspot, hittracer.Results, "LaserBeam", "LaserHit", damage, 0, !(level.time % Random(25, 45)), 1.0);

		if (!flare2 && (!master || !(master is "LaserCube" || master is "PortalSpot"))) { flare2 = Spawn("Flare", pos + hittracer.Results.HitVector * 12.0, ALLOW_REPLACE); }
		if (flare2)
		{
			flare2.master = self;
			flare2.alpha = 0.9;
			flare2.scale.x = flare2.Default.scale.x * FRandom(0.8, 1.0);
			flare2.scale.y = flare2.Default.scale.y * FRandom(0.8, 1.0);
			flare2.SetXYZ(pos + hittracer.Results.HitVector * 12.0);
		}

		if (hitspot)
		{
			if (!flare) { flare = Spawn("Flare", hitspot.pos, ALLOW_REPLACE); }
			if (flare)
			{
				flare.master = self;
				flare.alpha = 0.7 + FRandom(-0.2, 0.2);
				flare.scale.x = flare.Default.scale.x * FRandom(0.2, 0.5);
				flare.scale.y = flare.Default.scale.y * FRandom(0.2, 0.5);
				flare.SetXYZ(hitspot.pos);
			}
		}
	}

	void DoTrace(Actor origin, double angle, double dist, double pitch, int flags, double zoffset, LaserFindHitPointTracer thistracer)
	{
		if (!thistracer) { return; }

		if (!origin) { origin = self; }

		thistracer.skipspecies = origin.species;
		thistracer.skipactor = origin;

		Vector3 tracedir = (cos(angle) * cos(pitch), sin(angle) * cos(pitch), -sin(pitch));
		thistracer.Trace(origin.pos + (0, 0, zoffset), origin.CurSector, tracedir, dist, 0);
	}

	override void Activate(Actor activator)
	{
		bDormant = false;
		SetStateLabel("Active");
		Super.Activate(activator);
	}

	override void Deactivate(Actor activator)
	{
		bDormant = true;
		SetStateLabel("Inactive");

		A_StopSound(CHAN_6);

		if (beam) { beam.Destroy(); }
		if (hitspot) { hitspot.Destroy(); }
		if (flare) { flare.Destroy(); }
		if (flare2) { flare2.Destroy(); }

		Super.Deactivate(activator);
	}
}

class HitMarker : Actor
{
	bool moved;
	Vector3 oldpos;
	Class<Actor> spot;

	Property Spot:spot;

	Default
	{
		Radius 1;
		Height 1;
		+NOINTERACTION
		+NOGRAVITY
		+INVISIBLE
		+INTERPOLATEANGLES
	}

	States
	{
		Spawn:
			AMRK A -1;
			Stop;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER);
	}

	override void Tick()
	{
		if (!master) { Destroy(); }
		else
		{
			angle = master.angle;
			pitch = master.pitch;
		}

		moved = (pos != oldpos);

		Super.Tick();

		oldpos = pos;
	}

	override void OnDestroy()
	{
		if (Alternative) { Alternative.Destroy(); }
	}
}

class LaserHitMarker : HitMarker
{
	Default
	{
		HitMarker.Spot "LaserSpot";
	}
}

class LaserEmitter : LaserSpot
{
	Default
	{
		//$Category Portal/Objects
		//$Title Laser Emitter
		-INVISIBLE
		Scale 1.2;
	}

	States
	{
		Active:
			UNKN A 1
			{
				A_FireLaser(3, "laser/loop");
			}
			Loop;
	}
}

class LaserEmitterBlue : LaserSpot
{
	States
	{
		Spawn:
		Active:
			UNKN A 1
			{
				A_FireGuideLaser("laser/loop");
			}
			Loop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		double zoffset;
		if (master) { zoffset = pos.z - master.pos.z; }

		DoTrace(master, angle, 2048, pitch, 0, zoffset, hittracer);
	}

	void A_FireGuideLaser(sound snd = "")
	{
		if (snd != "")
		{
			A_StartSound(snd, CHAN_6, CHANF_NOSTOP | CHANF_LOOP, 0.0125, ATTN_STATIC);
		}

		[beam, hitspot] = Utilities.DrawLaser(self, beam, hitspot, hittracer.Results, "LaserBeamBlue", "", damage, 0, false, 0.75);
	}
}

class BridgeSpot : Actor
{
	BridgeFindHitPointTracer hittracer;
	Actor hitspot;

	Default
	{
		+NOGRAVITY
		+NOINTERACTION
		+NOBLOCKMAP
		+INVISIBLE
		Species "Bridge";
		Radius 0;
		Height 0;
	}

	States
	{
		Spawn:
		Inactive:
			UNKN A 1 A_RemoveChildren(true, RMVF_EVERYTHING);
		Idle:
			UNKN A 1;
			Loop;
		Active:
			UNKN A 1 A_RemoveChildren(true, RMVF_EVERYTHING); // Make sure the bridge doesn't double-draw if it's activated multiple times somehow
			UNKN A 1 A_FireBeam();
		ActiveLoop:
			UNKN A 1;
			Loop;
	}

	override void PostBeginPlay()
	{
		hittracer = new("BridgeFindHitPointTracer");

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		Super.Tick();

		if (master)
		{
			pitch = master.pitch;
			if (master is "PortalSpot" && Distance3D(master) > 32.0) { Destroy(); }
		}
	}

	void A_FireBeam()
	{
		StartSoundSequence("BridgeUp", 0);

		DoBridgeTrace(master, angle, 2048, pitch, 0, 0, hittracer);
		DrawBridge(hittracer.Results);
	}

	action void DoBridgeTrace(Actor origin, double angle, double dist, double pitch, int flags, double zoffset, BridgeFindHitPointTracer thistracer)
	{
		if (!thistracer) { return; }

		if (!origin) { origin = self; }

		Vector3 tracedir = (cos(angle) * cos(pitch), sin(angle) * cos(pitch), -sin(pitch));
		thistracer.Trace(origin.pos + (0, 0, zoffset), origin.CurSector, tracedir, dist, 0);
	}

	void DrawBridge(TraceResults traceresults, Class<Actor> spawnclass = "BridgeBeam", double sparsity = 32.0)
	{
		if (!traceresults) { return; }

		int steps = int(traceresults.Distance / sparsity);

		double radiusoffset = traceresults.HitActor ? traceresults.HitActor.radius : 0;

		Actor mo;
		Vector3 position;

		for (int i = steps; i >= 0; i--)
		{
			position = pos + traceresults.HitVector * sparsity * i;

			mo = Spawn(spawnclass, position, ALLOW_REPLACE);
			if (mo)
			{
				mo.master = self;
				mo.pitch = pitch;
				mo.angle = angle;

				if (mo is "BridgeBeam") { BridgeBeam(mo).delay = level.time + i; }
			}
		}

		// Last one is decorative only and embedded in wall so the bridge always looks complete
		mo = Spawn(spawnclass, pos + traceresults.HitVector * sparsity * (steps + 1), ALLOW_REPLACE);
		if (mo)
		{
			mo.bNoInteraction = true;
			mo.bSolid = false;
			mo.master = self;
			mo.pitch = pitch;
			mo.angle = angle;

			if (mo is "BridgeBeam") { BridgeBeam(mo).delay = level.time + steps + 1; }
		}

		if (!hitspot) { hitspot = Spawn("BridgeHitMarker", traceresults.HitPos - traceresults.HitVector * radiusoffset, ALLOW_REPLACE); }
		if (hitspot)
		{
			hitspot.master = self;
		}
	}

	override void Deactivate(Actor activator)
	{
		StartSoundSequence("BridgeDown", 0);

		A_RemoveChildren(true, RMVF_EVERYTHING);

		Super.Deactivate(activator);
	}
}

class BridgeHitMarker : LaserHitMarker
{
	Default
	{
		HitMarker.Spot "BridgeSpot";
	}

	override void PostBeginPlay()
	{
		if (master)
		{
			Actor spot = Spawn("PortalMapSpot", pos + (RotateVector((1, 0), master.angle + 180), 24));
			if (spot)
			{
				spot.angle = master.angle + 180;
			}
		}

		Super.PostBeginPlay();
	}
}

class BridgeBeam : Actor
{
	Actor light;
	int delay;
	double volume;
	double dist;

	Default
	{
		+SOLID
		+NOGRAVITY
		Radius 10.0;
		Height 1;
		RenderStyle "Add";
		Alpha 0.0;
	}

	States
	{
		Spawn:
			UNKN A 5;
			Loop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		if (!light && !bNoInteraction)
		{
			light = Spawn("AlphaLight", pos);

			if (light)
			{
				light.master = self;
				DynamicLight(light).bAttenuate = true;
				AlphaLight(light).maxradius = 20.0;
				AlphaLight(light).clr = color("00 7B FF");
			}
		}

		if (master) { dist = Distance3D(master); }
	}


	override void Tick()
	{
		Super.Tick();

		if (!master)
		{
			Destroy();
		}
		else if (level.time > delay)
		{
			alpha = 0.8 + 0.1 * sin(3 * level.time - dist);

			if (light)
			{
				light.SetXYZ(pos);
				light.alpha = 0.5 + 0.4 * sin(3 * level.time - dist);
			}
		}
	}

	override void OnDestroy()
	{
		if (light) { light.Destroy(); }
	}
}

class BridgeEmitter : BridgeSpot
{
	Default
	{
		//$Category Portal/Objects
		//$Title Light Bridge Emitter
		-INVISIBLE
		Scale 1.2;
	}
}

class DripStream : LaserBeam
{
	Default
	{
		-BRIGHT
	}

	override void Tick()
	{
		if (IsFrozen()) { return; }

		if (playeringame[consoleplayer] && players[consoleplayer].mo) { A_Face(players[consoleplayer].mo, 0, 270, 90); }

		Super.Tick();
	}
}

class DripEmitter : LaserSpot
{
	Actor splash;
	Vector3 splashpos;

	Default
	{
		//$Category Portal/Effects
		//$Title Water Stream
	}

	States
	{
		Spawn:
		Active:
			AMRK A 1
			{
				A_DripStream();
			}
			Loop;
	}

	void A_DripStream()
	{
		hittracer.skipspecies = species;
		hittracer.skipactor = self;

		pitch = -90;

		Vector3 tracedir = (0, 0, -1);
		hittracer.Trace(pos, CurSector, tracedir, 2048.0, 0);

		beam = Utilities.DrawLaser(self, beam, hitspot, hittracer.Results, "DripStream", "", 0, 0, false, 1.0, "");

		if (!splash)
		{
			splash = Spawn("DripSplash", hittracer.Results.HitPos, ALLOW_REPLACE);
			if (splash) { splash.master = self; }
		}

		if (splash && hittracer.Results.HitPos != splashpos)
		{
			splash.SetOrigin(hittracer.Results.HitPos, true);
			splashpos = hittracer.Results.HitPos;
		}
	}

}

class DripSplash : Actor
{
	int interval;

	Default
	{
		+NOGRAVITY
		+NOINTERACTION
		+NOBLOCKMAP
		+FORCEXYBILLBOARD
		+ROLLSPRITE
		Radius 0;
		Height 0;
		RenderStyle "Add";
		Alpha 0.4;
		Scale 0.03125;
	}
	States
	{
		Spawn:
			SPLA AAAA 1
			{
				A_FadeOut(Default.alpha / 4);
				scale *= 1.1;
			}
			SPLA A 0
			{
				roll = Random(1, 360);
				alpha = Default.alpha;
				scale = Default.scale;
			}
			Loop;
	}

	override void Tick()
	{
		if (!master) { Destroy(); }

		A_StartSound("drip/loop", CHAN_6, CHANF_NOSTOP | CHANF_LOOP, 0.0625, ATTN_STATIC);

		Super.Tick();
	}
}
