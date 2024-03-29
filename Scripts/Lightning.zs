// Lots of bits and pieces from D4D's Lightning Gun used originally... Significantly modified by AFADoomer for Blade of Agony, then further modified.

Class LightningPuff : Actor
{
	Default 
	{
		Projectile;
		+BLOODLESSIMPACT
		+DONTSPLASH
		+NOINTERACTION
		+NOTONAUTOMAP
		Radius 0;
		Height 0;
		RenderStyle "None";
		Decal "LightningScorch";
		DamageType "Electric";
	}

	States
	{
		Spawn:
			TNT1 A 10;
			Stop;
		Crash:
			TNT1 A 10 A_SpawnSparks();
			Stop;
	}

	void A_SpawnSparks()
	{
		if (Random(0, 6)) { return; }

		Actor sparks = Spawn("SparkSpawner", pos);
		if (sparks)
		{
			sparks.angle = angle;
			sparks.pitch = pitch - 90;
			SparkSpawner(sparks).silent = true;
			sparks.tics = Random(2, 5);
		}
	}
}

// Base class that spawns the actual beam segments
Class LightningBeam : Actor 
{
	Vector3 AimPoint;

	Actor closest;
	Actor origin;
	String trail;
	bool targets;
	double AngleRandom;
	double CurDistance;
	double MaxDistance;
	double MaxScale;
	double MinScale;
	double PitchRandom;
	double StepDistance;
	double faceamt;
	double splitamt;
	double stepfactor;
	int Choke;
	int ChokeMax;
	int ChokeMin;
	int child;

	Property AllowSplit:splitamt;
	Property AngleRandom:AngleRandom;
	Property ChokeMax:ChokeMax;
	Property ChokeMin:ChokeMin;
	Property FaceAmount:faceamt;
	Property MaxDistance:MaxDistance;
	Property MaxScale:MaxScale;
	Property MinScale:MinScale;
	Property PitchRandom:PitchRandom;
	Property StepFactor:stepfactor;
	Property TrailActor:trail;
	Property targets:targets;

	Default 
	{
		+NOBLOCKMAP
		+NOINTERACTION
		+INTERPOLATEANGLES
		RenderStyle "None";
		ActiveSound "electrical/shock";

		LightningBeam.AngleRandom 5;
		LightningBeam.ChokeMax 3;
		LightningBeam.ChokeMin 1;
		LightningBeam.FaceAmount 5;
		LightningBeam.MaxDistance 256;
		LightningBeam.MaxScale 0.03;
		LightningBeam.MinScale 0.0125;
		LightningBeam.PitchRandom 5;
		LightningBeam.StepFactor 1;
		LightningBeam.TrailActor "LightningTrailBeamArc";

		Obituary "$ELECTROCUTION";
	}

	States
	{
		Spawn:
			TNT1 A 1 NODELAY A_SpawnBeam();
			Stop;
	}

	override void PostBeginPlay()
	{
		if (master)
		{
			origin = master;
		}

		Choke = Random(ChokeMin, ChokeMax);

		StepDistance = Random[steps](5, 7) * stepfactor;

		if (Scale.X == 1.0) { Scale.X = MaxScale; }

		Scale.Y = StepDistance;

		if (AimPoint == (0, 0, 0))
		{
			FLineTraceData trace;
			LineTrace(angle, MaxDistance, pitch, TRF_THRUHITSCAN | TRF_THRUACTORS, 0.0, 0.0, 0.0, trace);

			AimPoint = trace.HitLocation;
		}

		tracer = Spawn("TargetActor", AimPoint);

		Super.PostBeginPlay();
	}

	void A_SpawnBeam()
	{
		// Due to how lightning damage is handled, even though the beam is drawn right next to the spawning 
		//  actor, it doesn't do damage within 4 * Radius distance from the spawning actor.  This call below 
		//  makes sure that damage of the correct amount and type still occurs inside of that radius...
		Class<MovingTrailBeam> trailclass = trail;
		let def = GetDefaultByType(trailclass);
		if (!def) { return; }

		if (master && master.radius && def.damage) { master.A_CustomBulletAttack(angle - master.angle, 0, 1, def ? def.Damage : Random(0, 1), MovingTrailBeam(def) ? MovingTrailBeam(def).puff : "LightningPuff", master.radius * 4, CBAF_AIMFACING | CBAF_EXPLICITANGLE); }

		Actor prev;

		A_StartSound(ActiveSound, CHAN_AUTO, 0, 0.5, ATTN_STATIC);

		While (CurDistance < MaxDistance - StepDistance)
		{
			if (CurDistance > 0 && !level.IsPointInLevel(pos)) { return; }

			bool spawned;
			Actor t;

			if (targets && (!closest || level.time % 15 == 0)) // Only run this every fifteen tics, or on first iteration
			{
				closest = ClosestMonster();
				if (closest) { tracer = closest; }
			}

			A_Face(tracer, faceamt, 0, 0, 0, FAF_MIDDLE);

			Scale.X = MinScale + (MaxDistance - CurDistance) * (MaxScale - MinScale) / MaxDistance;

			if (
				(
					!master ||
					!(master is "PlayerPawn") ||
					CurDistance > Min(32, MaxDistance / 4)
				) &&
				CurDistance < (MaxDistance - StepDistance)
			)
			{
				// D4D Code
				// If we're not about to reach the end, or not hitting the 
				// Choker, randomize it. Otherwise, stay on target and go 
				// for the puff.
				if (Choke > 0)
				{
					pitch = pitch + FRandom[pitch](0, PitchRandom) * RandomPick[pitchdir](-1, 1);
					angle = angle + FRandom[angle](0, AngleRandom) * RandomPick[angledir](-1, 1);

					Choke = max(0, Choke -1);
				}
				else if (CurDistance < (MaxDistance - StepDistance * 3))
				{
					Choke = Random(ChokeMin, ChokeMax);
				}

				// Spawn a split from the main beam
				if (splitamt > 0 && scale.x > 0.001 && Random[split]() < 10 * splitamt * (child + 1) && child < ChokeMax + 2)
				{
					t = Spawn(GetClass(), pos + (RotateVector((cos(pitch), 0), angle), -sin(pitch)));
					if (t) {
						t.master = master;
						t.pitch = FRandom[splitpitch](pitch - PitchRandom, pitch + PitchRandom);
						t.angle = FRandom[splitangle](angle - AngleRandom, angle + AngleRandom);
						t.tracer = tracer;
						LightningBeam(t).AimPoint = AimPoint;
						LightningBeam(t).MaxDistance = 32;
						LightningBeam(t).child = child + 1;
						LightningBeam(t).StepFactor = stepfactor;
						LightningBeam(t).StepDistance = stepdistance;
						LightningBeam(t).MaxScale = scale.x;
						LightningBeam(t).closest = closest;
						t.scale.x = scale.x / (child + 1);
						t.target = target;
					}
				}
			}

			// Spawn call here was originally D4D Code using A_SpawnItemEx
			// Spawn the beam with the same angle and pitch. Note that the
			// beam is being centered so we have to take that into account
			// and spawn it FORWARD based on half the beam's length.
			// Then move forward by a beam's length and repeat until done.
			t = Spawn(trail, pos + (RotateVector((cos(-pitch) * StepDistance / 2.0, 0), angle), sin(-pitch) * StepDistance / 2.0));
			if (t)
			{
				if (t.waterlevel > 0 || (curSector.GetTerrain(Sector.floor) > 0 && t.pos.z <= floorz + 4))
				{
					if (pitch != 0)
					{
						t.Destroy(); // Destroy this one and spawn a new one with flat pitch, so it goes along the surface of the water

						pitch = 0;
						PitchRandom = 0;
						AngleRandom = 45;

						t = Spawn(trail, pos + (RotateVector((StepDistance / 2.0, 0), angle), 0));
					}

					if (t) { ElectrifySector(t.CurSector, MovingTrailBeam(t).Damage, t.pos); }
				}

				t.master = master;
				t.angle = angle;
				t.pitch = pitch + 90;
				t.scale = scale;
				t.target = target;
				t.tracer = tracer;
			}

			SetXYZ(pos + (RotateVector((cos(-pitch) * StepDistance, 0), angle), sin(-pitch) * StepDistance));

			prev = t;

			CurDistance += StepDistance;
		}
	}

	void ElectrifySector(Sector cur, int damage = -1, Vector3 origin = (0, 0, 0))
	{
		int floorcount = cur.Get3dFloorCount();

		for (int c = 0; c < floorcount; c++)
		{
			F3DFloor f = cur.Get3DFloor(c);

			if (f.top.d >= pos.z  && !!(f.flags & F3DFloor.FF_EXISTS | F3DFloor.FF_SWIMMABLE))
			{
				SectorDamageHandler.SetDamage(f.model, damage > -1 ? damage : Random(0, 2), "Electric", 1, 35);
				if (origin.length()) { DrawZaps(f.model, origin); }
			}
		}

		if (!floorcount)
		{
			ZapSector(cur, damage);
			if (origin.length()) { DrawZaps(cur, origin); }
		}
	}

	void ZapSector(Sector cur, int damage = -1)
	{
		for (Actor mo = cur.thinglist; mo != null; mo = mo.snext)
		{
			if ((mo.pos.z <= floorz || mo.waterlevel > 0) && mo.bShootable) { mo.DamageMobj(self, self, damage > 0 ? damage : Random(0, 2), "Electric"); }
		}
	}

	void DrawZaps(Sector sec, Vector3 pos)
	{
		if (!sec) { return; }

		Vector2 offset;
		double range = 768.0;
		offset.x = FRandom(-range, range);
		offset.y = FRandom(-range, range);

		pos += (offset, 0);

		if (level.IsPointInLevel(pos))
		{
			Sector destsec = level.PointInSector(pos.xy);
			if (destsec == sec)
			{
				Spawn("Zap", pos);
			}
			else
			{
				int floorcount = destsec.Get3dFloorCount();

				for (int c = 0; c < floorcount; c++)
				{
					F3DFloor f = destsec.Get3DFloor(c);

					if (f.model == sec)
					{
						Spawn("Zap", pos);
					}
				}
			}
		}
	}

	actor ClosestMonster(void)
	{
		Actor mo, closest;

		if (master is "PlayerPawn" || master.bFriendly == true)
		{
			BlockThingsIterator it = BlockThingsIterator.Create(self, 256);

			while (it.Next())
			{
				mo = it.thing;

				if (mo == self || mo == origin || !mo.bShootable || mo.bDormant) { continue; }
				if (!origin.IsVisible(mo, true)) { continue; }
				if (Distance3d(mo) > 256) { continue; }
				if (closest && Distance3d(mo) > Distance3d(closest)) { continue; }

				closest = mo;
			}
		}
		else
		{
			for (int p = 0; p < MAXPLAYERS; p++)	
			{ // Iterate through all of the players and find the closest one
				mo = players[p].mo;

				if (mo)
				{
					if (!mo.bShootable || mo.health <= 0) { continue; }
					if (players[p].cheats & CF_NOTARGET) { continue; }
					if (closest && Distance3d(mo) > Distance3d(closest)) { continue; }

					closest = mo;
				}
			}
		}

		return closest;
	}
}

Class Zap : Actor
{
	Default
	{
		+FLATSPRITE
		+NOGRAVITY
		Scale 0.25;
		RenderStyle "Add";
		Alpha 0.125;
	}

	States
	{
		Spawn:
			PLSE ABCDE 1 Bright;
			Stop;
	}

	override void Tick()
	{
		Super.Tick();

		A_AttachLight("BeamLight", DynamicLight.FlickerLight, 0x707080, 1, 8, DynamicLight.LF_ATTENUATE, (0, 0, 0.1));
	}
}

Class LightningBeamArc : LightningBeam
{
	Default 
	{
		LightningBeam.AngleRandom 4;
		LightningBeam.ChokeMax 4;
		LightningBeam.ChokeMin 2;
		LightningBeam.MaxDistance 1024;
		LightningBeam.MaxScale 0.02;
		LightningBeam.MinScale 0.01;
		LightningBeam.PitchRandom 4;
		LightningBeam.StepFactor 2.5;
		LightningBeam.FaceAmount 15;
		LightningBeam.TrailActor "LightningTrailBeamArc";
	}
}


// Base class for the beam segments
Class MovingTrailBeam : Actor 
{
	String puff;
	Vector3 beamoffset;
	int damage;

	Property Damage:damage;
	Property PuffActor:puff;

	Default
	{
		Height 1;
		Radius 0;
		+BRIGHT
		+NOINTERACTION
		RenderStyle "Add";
		MovingTrailBeam.Damage 0;
		MovingTrailBeam.PuffActor "LightningPuff";
	}

	States
	{
		Spawn:
			MDLA A 0;
		Fade:
			MDLA A 1 A_FadeOut(0.2);
			Goto Fade;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		if (master)
		{ 
			if (damage > 0 && (!master.bShootable || Distance3D(master) > master.radius * 4))
			{
				// Used to make all individual bolt segments leave decals and cause damage
				LineAttack(angle, scale.y, pitch - 90, damage, "Electric", puff, 0, null, -8.5);
			}

			beamoffset = pos - master.pos;
		}

		if (pos.z < floorz) { Destroy(); }

		A_AttachLight("BeamLight", DynamicLight.PointLight, 0xFF707080, int(scale.y), 0, DynamicLight.LF_ATTENUATE | DynamicLight.LF_SPOT, (-scale.y, 0, 1.0), 0, 10, 30, 0);
	}

	override void Tick()
	{
		Super.Tick();

		if (IsFrozen()) { return; }

		if (master && master is "PlayerPawn")
		{ 
			SetXYZ(master.pos + beamoffset);
		}
	}

}

Class LightningTrailBeamArc : MovingTrailBeam
{
	Default
	{
		+BRIGHT
		MovingTrailBeam.Damage 10;
	}
}

Class TargetActor : Actor
{
	Vector3 offset;

	Default
	{
		Height 0;
		Radius 0;
		+NOINTERACTION;
	}

	States
	{
		Spawn:
			TNT1 A 1;
			Stop;
	}

	override void PostBeginPlay()
	{
		if (master) { offset = pos - master.pos; }

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		if (master)
		{
			SetXYZ(master.pos + offset);
		}

		Super.Tick();
	}
}

class ElectricalArc : SwitchableDecoration
{
	Class<LightningBeam> beam;

	Property Beam:beam;

	Default
	{
		//$Category Portal/Effects
		//$Title Electrical Arc
		//$Sprite AMRKA0
		//$Color 3
		+NOGRAVITY
		Height 0;
		Radius 0;
		ElectricalArc.Beam "LightningBeamArc";
	}

	States
	{
		Spawn:
		Active:
			TNT1 A 2 A_LightningBeam(beam);
			Loop;
		Inactive:
			TNT1 A 1;
			Loop;
	}

	void A_LightningBeam(Class<LightningBeam> beam = "LightningBeamArc")
	{
		if (bStandstill) { return; }

		bool spawned;
		Actor p;

		p = Spawn(beam, pos);
		if (LightningBeam(p))
		{
			p.master = self;
			p.pitch = pitch;
			p.angle = angle;
		}
	}

	override void Activate(Actor activator)
	{
		SetStateLabel("Active");
		Super.Activate(activator);
	}

	override void Deactivate(Actor activator)
	{
		SetStateLabel("Inactive");
		Super.Deactivate(activator);
	}

}