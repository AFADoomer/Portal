class Turret : CarryActor
{
	LaserFindHitPointTracer hittracer;
	LaserBeam beam;
	Actor hitspot;
	double spawnangle, spawnpitch, laserzoffset;
	LookExParams params;
	bool canattack;

	Default
	{
		Monster;
		-NODAMAGE

		Health 20;
		Radius 16;
		Height 32;
		Speed 0;
		Mass 100;
		PainChance 200;

		SeeSound "grunt/sight";
		AttackSound "grunt/attack";
		PainSound "grunt/pain";
		DeathSound "grunt/death";
		ActiveSound "grunt/active";
		Obituary "$OB_TURRET";
		CarryActor.Fizzle True;
		CarryActor.Explode True;
	}

	States
	{
		Spawn:
			UNKN A 10 A_Look;
			Loop;
		See:
			UNKN A 1;
			UNKN A 0 {
				if (master is "PlayerPawn")
				{
					spawnangle = Normalize180(angle);
					if (target == master) { target = null; }
				}
				else if (canattack)
				{
					A_Chase("Missile", "Missile", CHF_DONTMOVE | CHF_NODIRECTIONTURN | CHF_NOPOSTATTACKTURN);
				}
				else
				{
					A_Chase(null, null, CHF_DONTMOVE | CHF_NODIRECTIONTURN | CHF_NOPOSTATTACKTURN);
				}
			}
			Loop;
		Missile:
			UNKN A 35;
		Missile.Loop:
			UNKN A 5 A_Attack;
			UNKN A 0 A_DoRefire;
			Goto Missile.Loop;
		Pain:
			UNKN A 3;
			UNKN A 3 A_Pain;
			Goto See;
		Death:
		XDeath:
			UNKN A 15;
		Fall.Loop:
			UNKN A 35;
			UNKN A 0 { if (pos.z > floorz + zoffset && !bOnMobj && vel.length()) { SetStateLabel("Fall.Loop"); } }
			Goto Super::Death.Explode;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER);
	}

	override void PostBeginPlay()
	{
		hittracer = new("LaserFindHitPointTracer");

		spawnangle = Normalize180(angle);
		spawnpitch = Normalize180(pitch);
		laserzoffset = height * 3 / 4;

		params.fov = 45.0;
		params.mindist = 0;
		params.maxdist = 1024;
		params.maxheardist = 128;

		Super.PostBeginPlay();

		pushfactor = 0.1;
	}

	override void Tick()
	{
		Super.Tick();

		if (!target || !IsVisible(target, bLookAllAround, params))
		{
			if (target)
			{
				target = null;
			}

			FaceTo(spawnangle, spawnpitch);
			canattack = false;
		}
		else if (target && abs(deltaangle(AngleTo(target), spawnangle)) < params.fov)
		{
			canattack = FaceTo(AngleTo(target), -Utilities.PitchTo(target, self, laserzoffset, target.height / 2), speed:0.1);
		}
		else
		{
			target = null;
		}

		DoTrace(master, angle, 2048, pitch, 0, laserzoffset, hittracer);
		[beam, hitspot] = Utilities.DrawLaser(self, beam, hitspot, hittracer.Results, "LaserBeamSight", "", 0, laserzoffset, false, 0.25);

		if (SpawnTime + 35 < level.time && !master && health > 0 && vel.length() > 8.0 && !InStateSequence(CurState, FindState("Death")))
		{
			health = 0;
			SetStateLabel("Death");
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

	void A_Attack()
	{
		if (target)
		{
			double ang = angle + FRandom[AttackAngle](-2.0, 2.0);
			double slope = pitch + FRandom[AttackPitch](-2.0, 2.0);
			int damage = Random[Attack](10, 16);

			A_StartSound(AttackSound, CHAN_WEAPON);

			LineAttack(ang, MISSILERANGE, slope, damage, "Hitscan", "Bulletpuff"); //, offsetz:zoffset);
		}
	}

	void A_DoRefire()
	{
		if (
			!target || 
			target == master || 
			HitFriend() ||
			target.health <= 0 ||
			!IsVisible(target, false, params)
		)
		{
			SetState(SeeState);
		}
	}

	bool FaceTo(double targetangle, double targetpitch, double anglelimit = 45.0, double pitchlimit = 45.0, double speed = 1.0)
	{
		bool done = true;

		if (abs(deltaangle(targetangle, spawnangle)) >= anglelimit) { targetangle = targetangle > 0 ? spawnangle + anglelimit : spawnangle - anglelimit; }
		int adelta = int(deltaangle(angle, targetangle));
		if (abs(adelta) > 3)
		{
			angle += adelta * 1.9 * speed;
			angle = clamp(Normalize180(angle), spawnangle - anglelimit, spawnangle + anglelimit);
			done = false;
		}
		else { angle = targetangle; }

		if (abs(deltaangle(targetpitch, spawnpitch)) >= pitchlimit) { targetpitch = targetpitch > 0 ? spawnpitch + pitchlimit : spawnpitch - pitchlimit; }
		int pdelta = int(deltaangle(pitch, targetpitch));
		if (abs(pdelta) > 3)
		{
			pitch += pdelta * 1.9 * speed;
			done = false;
		}
		else { pitch = targetpitch; }

		return done;
	}
}