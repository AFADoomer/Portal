class Platform : Actor
{
	Actor glass;
	bool floating;

	Default
	{
		//$Category Portal/Platforms
		+NOGRAVITY
		+DONTTHRUST
		+SOLID
		+MOVEWITHSECTOR
		+CANPASS
		Height 3;
		Radius 32;
	}

	States
	{
		Spawn:
			UNKN A -1;
			Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		bDormant = SpawnFlags & MTF_DORMANT;

		if (bStandstill) { floating = true; }

		while (!glass) { glass = Spawn("PlatformGlass", pos); }
		glass.master = self;
		glass.alpha = 0.25;
		glass.frame = 0;
	}

	override void Tick()
	{
		if (!floating)
		{
			SetOrigin((pos.xy, floorz), true);
			if (glass) { glass.SetXYZ(pos); }
		}

		Super.Tick();
	}

	override void OnDestroy()
	{
		if (glass) { glass.Destroy(); }
	}
}

class PlatformMoving : Platform
{
	Array<Actor> touchers;
	Vector3[64] offsets;
	LaserFindHitPointTracer beamtracer;
	Actor beam;

	Default
	{
		//$Title Platform (Moving)
		-MOVEWITHSECTOR
		MaxStepHeight 0;
		Speed 2;
	}


	States
	{
		Spawn:
			UNKN A 1;
		Active:
			UNKN A 1
			{
				bStandStill = False;
				bDormant = False;
				A_StartSound("platform2/start", CHAN_AUTO, 0, 0.25);
			}
			UNKN A 245;
		ActiveLoop:
			UNKN A 1 { A_StartSound("platform2/loop", CHAN_6, CHANF_LOOP, 0.25); }
			Loop;
		Inactive:
			UNKN A 1
			{
				A_StopSound(CHAN_6);
				bStandStill = True;
				A_StartSound("platform2/stop", CHAN_AUTO, 0, 0.25);
			}
		InactiveLoop:
			UNKN A 1;
			Loop;
	}

	override void Touch(Actor toucher)
	{
		if (toucher == self || toucher == glass || toucher.bNoGravity || toucher is "Platform" || toucher is "BlockBase") { return; }
		if (toucher.pos.z > pos.z + 32.0 || toucher.pos.z < pos.z - 16) { return; }
		if (toucher.master && touchers.Find(toucher.master)) { return; }
		if (touchers.Find(toucher) == touchers.Size()) { touchers.Push(toucher); }
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		if (bDormant) { SetStateLabel("Inactive"); }

		beamtracer = new("LaserFindHitPointTracer");

		DoTrace(self, angle + 180, 2048, -pitch, 0, 0, beamtracer);
	}

	action void DoTrace(Actor origin, double angle, double dist, double pitch, int flags, double zoffset, LaserFindHitPointTracer thistracer)
	{
		if (!thistracer) { return; }

		if (!origin) { origin = self; }
		thistracer.skipactor = origin;
		thistracer.skipspecies = origin.species;

		Vector3 tracedir = (cos(angle) * cos(pitch), sin(angle) * cos(pitch), -sin(pitch));
		thistracer.Trace(origin.pos + (0, 0, zoffset), origin.CurSector, tracedir, dist, 0);
	}

	override void Tick()
	{
		if (IsFrozen() || bStandStill || bDormant)
		{
			Actor.Tick();

			if (beam) { beam.Destroy(); }
			return;
		}

		while (!beam)
		{
			beam = Spawn("LaserEmitterBlue", beamtracer.Results.HitPos + RotateVector((1, 0), angle) - (0, 0, 1));
			if (beam)
			{
				beam.angle = angle;
//				beam.pitch = pitch;
			}
		}

		CheckTouchers();

		for (int i = 0; i < min(touchers.Size(), 64); i++)
		{
			if (touchers[i])
			{
				if (
					Distance3D(touchers[i]) > (Radius + touchers[i].radius) * 1.4 ||
					touchers[i].pos.z + touchers[i].height < pos.z ||
					!touchers[i].bOnMobj
				) { touchers.Delete(i); }
				else { offsets[i] = touchers[i].pos - pos; }
			}
			else { touchers.Delete(i); touchers.ShrinkToFit(); }
		}

		Vector2 newpos = pos.xy + RotateVector((Speed, 0), angle);

		FCheckPosition checkpos;

		if (CheckMove(newpos, PCM_NOACTORS, checkpos)) //(!CheckMove(newpos, 0, checkpos) && !(checkpos.thing is "PlatformEndpoint")))
		{
			SetOrigin((newpos, pos.z), true);
			if (glass) { glass.SetXYZ(pos); }

			for (int i = 0; i < min(touchers.Size(), 64); i++)
			{
				if (
					touchers[i] && 
					(
						(Distance2D(touchers[i]) < (Radius + touchers[i].radius) * 1.4 && touchers[i].pos.z == pos.z + height) ||
						deltaangle(angle, AngleTo(touchers[i])) < 45 ||
						(touchers[i].bOnMobj && Distance3D(touchers[i]) < radius * 2)
					)
				)
				{
					if (touchers[i].CheckMove(pos.xy + offsets[i].xy)) { touchers[i].SetOrigin(pos + offsets[i], true); }
					else
					{
						if (touchers[i].pos.z < pos.z) { touchers[i].DamageMobj(self, self, int(5 * Speed), "Crush"); }
					}
				}
			}

			Actor.Tick();
		}
		else
		{
			angle = (angle + 180) % 360;
			Actor.Tick();
		}
	}

	void CheckTouchers()
	{
		BlockThingsIterator it = BlockThingsIterator.Create(self, Radius);
		Actor mo;

		while (it.Next() && (mo = it.thing))
		{
			if (Distance2D(mo) <= Radius + mo.Radius)
			{
				Touch(mo);
			}
		}
	}

}

class PlatformEndPoint : Column // Placeholder Actor
{
	Default
	{
		//$Category Portal/Platforms
		//$Title Platform Endpoint
	}
}

class PlatformWhite : Platform
{
	Default
	{
		//$Title Platform (White)
	}
}

class PlatformLiftStatic : Platform
{
	Default
	{
		//$Title Platform (Non-solid)
		-SOLID
		+NOINTERACTION
	}
}

class PlatformLiftStaticWhite : PlatformLiftStatic
{
	Default
	{
		//$Title Platform (White, Non-solid)
	}

}

class PlatformLift : PortalActor
{
	Actor glass;
	int user_moveheight, delay, maxheight;
	double user_speed;
	bool liftstate;

	Property LiftHeight:user_moveheight;
	Property LiftDelay:delay;
	Property LiftSpeed:user_speed;

	Default
	{
		//$Category Portal/Platforms
		//$Title Platform (Animated)
		//$Sprite "UNKNA0"
		+NOGRAVITY
		+DONTTHRUST
		+SOLID
		+MOVEWITHSECTOR
		+CANPASS
		Height 4;
		Radius 32;
		Speed 16;
		PlatformLift.LiftHeight 64;
		PlatformLift.LiftDelay 35;
		PlatformLift.Liftspeed 16;
		RenderRadius 256;
	}

	States
	{
		Inactive:
		Spawn:
			UNKN # -1;
			Stop;
		Raise:
			UNKN A 0 DoMove();
			UNKN B 0 DoMove();
			UNKN C 0 DoMove();
			UNKN D 0 DoMove();
			UNKN E 0 DoMove();
			UNKN F 0 DoMove();
			UNKN G 0 DoMove();
			UNKN H 0 DoMove();
			UNKN I 0 DoMove();
			UNKN J 0 DoMove();
			UNKN K 0 DoMove();
			UNKN L 0 DoMove();
			UNKN M 0 DoMove();
			UNKN N 0 DoMove();
			UNKN O 0 DoMove();
			UNKN P 0 DoMove();
			UNKN Q 0 DoMove();
			UNKN R 0 DoMove();
			UNKN S 0 DoMove();
			UNKN T 0 DoMove();
			UNKN U 0 DoMove();
			UNKN V 0 DoMove();
			UNKN W 0 DoMove();
			UNKN X 0 DoMove();
			UNKN Y 0 DoMove();
			UNKN Z 0 DoMove();
			Goto Spawn;
		Lower:
			UNKN Z 0 DoMove();
			UNKN Y 0 DoMove();
			UNKN X 0 DoMove();
			UNKN W 0 DoMove();
			UNKN V 0 DoMove();
			UNKN U 0 DoMove();
			UNKN T 0 DoMove();
			UNKN S 0 DoMove();
			UNKN R 0 DoMove();
			UNKN Q 0 DoMove();
			UNKN P 0 DoMove();
			UNKN O 0 DoMove();
			UNKN N 0 DoMove();
			UNKN M 0 DoMove();
			UNKN L 0 DoMove();
			UNKN K 0 DoMove();
			UNKN J 0 DoMove();
			UNKN I 0 DoMove();
			UNKN H 0 DoMove();
			UNKN G 0 DoMove();
			UNKN F 0 DoMove();
			UNKN E 0 DoMove();
			UNKN D 0 DoMove();
			UNKN C 0 DoMove();
			UNKN B 0 DoMove();
			UNKN A 0 DoMove();
			Goto Spawn;
		Active:
		Delay:
			UNKN # 1 A_SetTics(delay);
			UNKN # 0 {
				if (liftstate) { return ResolveState("Lower") + frame; }
				return ResolveState("Raise");
			} 
			Loop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		while (!glass) { glass = Spawn("PlatformGlass", pos); }
		glass.master = self;
		glass.alpha = 0.25;

		frame = 0;

		maxheight = user_moveheight;
		speed = user_speed;

		if (SpawnFlags & MTF_DORMANT) { SetStateLabel("Inactive"); }
		else { SetStateLabel("Active"); }
	}

	override void Tick()
	{
		Super.Tick();

		if (glass)
		{
			glass.frame = frame;
			glass.angle = angle;
			glass.pitch = pitch;
			glass.roll = roll;
		}
	}

	void DoMove()
	{
		if (!speed) { SetStateLabel("Spawn"); return; }

		A_SetTics(int(32 / max(Speed, 1)));

		if (!liftstate && int(user_moveheight / 4) == frame)
		{
			liftstate = !liftstate;
			user_moveheight = 0;
			SetStateLabel("Spawn");
		}
		else if (user_moveheight == 0 && frame == 0)
		{
			liftstate = !liftstate;
			user_moveheight = maxheight;
			SetStateLabel("Spawn");
		}
		else if (liftstate && frame > 0)
		{
			if (frame > int(maxheight / 4))
			{
				A_SetTics(0);
			}
		}

		A_SetSize(-1, frame * 4, false);
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

class PlatformGlass : PortalActor
{
	Default
	{
		+NOINTERACTION
		+NOGRAVITY
		+DONTTHRUST
		+MOVEWITHSECTOR
		RenderStyle "Translucent";
		Height 1;
		Radius 32;
		RenderRadius 256;
	}

	States
	{
		Spawn:
			UNKN # 1;
			Loop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		frame = 0;

		if (master) { scale = master.scale; }
	}
}
