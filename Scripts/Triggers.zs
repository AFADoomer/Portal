class CubeTrigger : Actor
{
	Array<Actor> Activators;
	bool active;
	int activationradius, timeout, movetimeout;
	Vector3 activatorpos;

	TextureID tex;

	Sector current;
	double h;
	transient F3DFloor current3d;

	double interval;

	Property ActivationRadius:activationradius;
	Property Timeout:timeout;

	Default
	{
		//$Category Portal/Objects
		//$Title Trigger - Weight Activated
		+SPECIAL
		+NOGRAVITY
		+NOLIFTDROP
		-SOLID
		+DONTTHRUST
		+NOINTERACTION
		Height 0;
		Radius 8;
		CubeTrigger.ActivationRadius 32;
		CubeTrigger.timeout 5;
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

		A_SetSize(activationradius);
		SpawnPoint = (pos.xy, max(pos.z, floorz));

		interval = Random(0, 9);

		[h, current, current3d] = curSector.NextLowestFloorAt(pos.x, pos.y, pos.z + 4);
	}

	override void Touch(Actor toucher)
	{
		if (Activators.Find(toucher) == Activators.Size()) { Activators.Push(toucher); }
	}

	override void Tick()
	{
		Super.Tick();

		if (isFrozen()) { return; }

		if (level.time % 10 == interval) { CheckActivators(); }

		for (int i = 0; i < Activators.Size(); i++)
		{
			if (Activators[i])
			{
				double zoffset = 0;
				if (Activators[i] is "CarryActor") { zoffset = CarryActor(Activators[i]).zoffset; }

				if (Distance2D(Activators[i]) <= Radius && Activators[i].pos.z - zoffset <= pos.z + height)
				{
					movetimeout = timeout;
				}
				else if (Distance2D(Activators[i]) > Radius || Activators[i].pos.z - zoffset > pos.z + height + 4)
				{
					Activators.Delete(i);
				}
			}
			else
			{
				Activators.Delete(i);
			}
		}

		if (!active)
		{
			if (Activators.Size())
			{
				tex = TexMan.CheckForTexture("BUTTONA", TexMan.Type_Any);

				if (current3d)
				{
				}
				else
				{
					current.MoveFloor(16.0, curSector.floorplane.d + 2, 0, 1, false);
					current.SetTexture(Sector.floor, tex);
				}

				Level.ExecuteSpecial(special, self, null, false, args[0], args[1], args[2] ? !active : active, args[3], args[4]);
				active = true;
				ActivatePeers(true);
				A_StartSound("button/down", CHAN_AUTO, 0, 0.5);

//				SetOrigin(SpawnPoint, false);
			}
		}
		else
		{
			if (movetimeout > 0) { movetimeout--; }

			if (movetimeout == 0 || !Activators.Size())
			{
				tex = TexMan.CheckForTexture("BUTTON", TexMan.Type_Any);

				if (current3d)
				{
				}
				else
				{
					current.MoveFloor(16.0, curSector.floorplane.d - 2, 0, -1, false);
					current.SetTexture(Sector.floor, tex);
				}

				Level.ExecuteSpecial(special, self, null, false, args[0], args[1], args[2] ? !active : active, args[3], args[4]);
				active = false;
				ActivatePeers(false);
				A_StartSound("button/up", CHAN_AUTO, 0, 0.5);

//				SetOrigin(SpawnPoint, false);
			}
		}
	}

	void CheckActivators()
	{
		for (int p = 0; p < MAXPLAYERS; p++)
		{
			if (
				playeringame[p] && players[p].mo &&
				Activators.Find(players[p].mo) == Activators.Size() &&
				Distance2D(players[p].mo) <= activationradius && 
				players[p].mo.pos.z <= pos.z + 4
			)
			{ Activators.Push(players[p].mo); }
		}

		ThinkerIterator it = ThinkerIterator.Create("Cube", Thinker.STAT_USER);
		Cube mo;

		while (mo = Cube(it.Next()))
		{
			if (
				Activators.Find(mo) == Activators.Size() &&
				Distance2D(mo) <= activationradius && 
				mo.pos.z - mo.zoffset <= pos.z + 4
			)
			{ Activators.Push(mo); }
		}
/*
		// Monsters can also activate buttons
		it = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);
		Actor mo2;

		while (mo2 = Actor(it.Next(false)))
		{
			if (
				mo2.bIsMonster &&
				Activators.Find(mo2) == Activators.Size() &&
				Distance2D(mo2) <= Radius && 
				mo2.pos.z <= pos.z + 4
			)
			{ Activators.Push(mo2); }
		}
*/
	}

	void ActivatePeers(bool OnOff)
	{
		ThinkerIterator it = ThinkerIterator.Create("Actor", Thinker.STAT_USER + 1);
		Actor mo;

		while (mo = Actor(it.Next(false)))
		{
			if (mo.tid == tid)
			{
				if (OnOff) { mo.SetStateLabel("Active"); }
				else { mo.SetStateLabel("Inactive"); }
			}
		}

	}
}

class SwitchTrigger : Actor
{
	bool active, move;
	int timeout, movetimeout, user_timeout, buttonstate;

	Property Timeout:timeout;

	Default
	{
		//$Category Portal/Objects
		//$Title Trigger - Use Activated
		+SPECIAL
		+INVISIBLE
		+NOGRAVITY
		+NOLIFTDROP
		-SOLID
		+DONTTHRUST
		Height 4;
		Radius 8;
		SwitchTrigger.timeout 60;
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

		if (user_timeout) { timeout = user_timeout; }
	}

	override bool Used(Actor user)
	{
		if (movetimeout <= 0 && ((user.pos.z < pos.z + 16.0 && user.pos.z > pos.z - user.height) || (PortalPlayer(user) && PortalPlayer(user).currentportal)))
		{
			active = !active;
			move = true;
			movetimeout = timeout;
			A_StartSound("switch/press", CHAN_AUTO, 0, 0.5);
		}

		return false;
	}

	override void Tick()
	{
		Super.Tick();

		if (IsFrozen()) { return; }

		Sector current;
		double h;
		F3DFloor current3d;

		[h, current, current3d] = curSector.NextLowestFloorAt(pos.x, pos.y, pos.z + 4);

		if (move)
		{
			if (!current3d)
			{
				curSector.MoveFloor(16.0, curSector.floorplane.d + 1, 0, 1, false);
			}

			Level.ExecuteSpecial(special, self, null, false, args[0], args[1], args[2] ? !active : active, args[3], args[4]);

			move = false;
			buttonstate = max(movetimeout - 5, 5);
		}
		else if (!buttonstate)
		{
			if (!current3d)
			{
				curSector.MoveFloor(16.0, curSector.floorplane.d - 1, 0, -1, false);
			}

			buttonstate = -1;
		}

		if (movetimeout > 0) { movetimeout--; }
		if (buttonstate > 0) { buttonstate--; }
	}
}

class PelletTrigger : Actor
{
	PortalFindHitPointTracer hittracer;

	Default
	{
		//$Category Portal/Objects
		//$Title Trigger - Pellet Activated
		+NOGRAVITY
		+NOLIFTDROP
		+SHOOTABLE
		+DONTTHRUST
		+NOBLOOD
		-SOLID
		Height 16;
		Radius 8;
	}

	States
	{
		Spawn:
			UNKN A 1;
			Loop;
	}

	override void PostBeginPlay()
	{
		hittracer = new("PortalFindHitPointTracer");

		Super.PostBeginPlay();

		DoTrace(self, angle, 2048, pitch - 90, 0, 0, hittracer);

		if (hittracer.Results.HitPos != (0, 0, 0))
		{
			let light = Spawn("AlphaLight", hittracer.Results.HitPos);

			if (light)
			{
				AlphaLight(light).clr = color(255, 64, 0);
				AlphaLight(light).maxradius = 32.0;
				AlphaLight(light).bAttenuate = true;
				light.alpha = 1.0;
 			}
		}
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (inflictor is "Pellet" || inflictor is "LaserBeam")
		{
			Level.ExecuteSpecial(special, null, null, false, args[0], args[1], args[2] ? 0 : 1, args[3], args[4]);
		}

		return 0;
	}

	void DoTrace(Actor origin, double angle, double dist, double pitch, int flags, double zoffset, PortalFindHitPointTracer thistracer)
	{
		if (!origin) { origin = self; }

		thistracer.skipspecies = origin.species;
		thistracer.skipactor = origin;
		Vector3 tracedir = (cos(angle) * cos(pitch), sin(angle) * cos(pitch), -sin(pitch));
		thistracer.Trace(origin.pos + (0, 0, zoffset), origin.CurSector, tracedir, dist, 0);
	}
}

class LaserTrigger : Actor
{
	int timeout;
	PortalFindHitPointTracer hittracer;
	int user_sound;

	Default
	{
		//$Category Portal/Objects
		//$Title Trigger - Laser Activated
		+NOGRAVITY
		+NOLIFTDROP
		+SHOOTABLE
		+DONTTHRUST
		+NOBLOOD
		-SOLID
		Height 16;
		Radius 8;
		Scale 1.2;
	}

	States
	{
		Spawn:
			UNKN A 1;
		SpawnLoop:
			UNKN # 1;
			Loop;
	}

	override void PostBeginPlay()
	{
		hittracer = new("PortalFindHitPointTracer");
		A_SetSize(Radius + 8 * abs(sin(pitch)));

		if (!user_sound) { user_sound = Random(1, 2); }
		if (user_sound > 0) { A_StartSound("laser/song" .. user_sound - 1, 8, CHANF_NOSTOP | CHANF_LOOP, 0.00001, ATTN_NORM, 0.75); } // Start on spawn so they stay in sync

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		Super.Tick();

		if (timeout > 0) { timeout--; }

		if (timeout == 0)
		{
			Level.ExecuteSpecial(special, self, null, false, args[0], args[1], args[2], args[3], args[4]);
			frame = 0;
			bBright = false;
			timeout = -1;
			if (level.time > 5) { A_StartSound("laser/target/off", CHAN_AUTO, 0, 0.5); }
			A_StopSound(CHAN_7);
			A_SoundVolume(8, 0.0);
		}
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (inflictor is "LaserBeam" && timeout < 0)
		{
			Level.ExecuteSpecial(special, self, null, false, args[0], args[1], !args[2], args[3], args[4]);
			frame = 1;
			bBright = true;
			A_StartSound("laser/target/on", CHAN_AUTO, 0, 0.25);
			A_StartSound("laser/target/loop", CHAN_7, CHANF_LOOP, 0.25);
			A_SoundVolume(8, 0.25);
		}

		timeout = 5;

		return 0;
	}
}

class WallSwitch : Actor
{
	bool active, moving, inuse;
	bool user_starton;
	int activationtimeout;
	Actor activator;

	Default
	{
		//$Category Portal/Objects
		//$Title Wall Switch
		+SPECIAL
		+NOGRAVITY
		+NOLIFTDROP
		-SOLID
		+DONTTHRUST
		Height 16;
		Radius 8;
	}

	States
	{
		Spawn:
			UNKN A -1;
			Stop;
		Active:
			UNKN BCDE 3;
		Activated:
			UNKN F -1 { moving = false; }
			Stop;
		Inactive:
			UNKN EDCB 3;
		Inactivated:
			UNKN A -1 { moving = false; }
			Stop;
	}

	override void PostBeginPlay()
	{
		activationtimeout = 1;

		if (user_starton)
		{
			SetStateLabel("Activated");
			active = true;
		}

		Super.PostBeginPlay();
	}

	override bool Used(Actor user)
	{
		if (inuse || moving) { return false; }

		moving = true;
		active = !active;

		if (active) { SetStateLabel("Active"); }
		else { SetStateLabel("Inactive"); }

		activator = user;

		return true;
	}

	override void Tick()
	{
		// Delay actual script call until after the switch stops moving
		if (activator && !moving)
		{
			Level.ExecuteSpecial(special, activator, null, false, args[0], args[1], args[2] ? !active : active, args[3], args[4]);
			A_StartSound(active ? "switch/on" : "switch/off", CHAN_AUTO, 0, 0.25);

			activator = null;
		}

		Super.Tick();
	}
}
