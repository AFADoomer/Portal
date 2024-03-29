class PortalPlayer : PlayerPawn
{
	Actor DragTarget, CurrentPortal, reflectioncamera, sparks;
	Weapon LastWeapon;
	bool useheld, party, carryblocked;
	int waterstate, stepdelay;
	Vector3 dragvel, oldvel;
	Sector activesector;
	UsePointTracer actortracer;
	CarryPointTracer carrytracer;
	Line lastline;
	TextureID AimTexture;
	Actor climbing;
	double AirSpeed;
	Array<Actor> touchers;
	bool step;
	int carryrange;

	Property CarryRange:carryrange;

	Default
	{
		Speed 0.5;
		Health 100;
		Radius 12;
		Height 56;
		Mass 100;
		PainChance 255;
		Gravity 0.45;
		MaxStepHeight 20;
		Player.JumpZ 3.5;
		Player.ViewBob 0.3;
		Player.UseRange 96.0;

		Player.DisplayName "Test Subject";
		Player.CrouchSprite "PLYC";
		Player.WeaponSlot 1, "PortalGun", "DualPortalGun";
		
		Player.ColorRange 112, 127;
		Player.Colorset 0, "Green", 0x70, 0x7F,  0x72;
		Player.Colorset 1, "Gray", 0x60, 0x6F,  0x62;
		Player.Colorset 2, "Brown", 0x40, 0x4F,  0x42;
		Player.Colorset 3, "Red", 0x20, 0x2F,  0x22;
		Player.Colorset 4, "Light Gray", 0x58, 0x67,  0x5A;
		Player.Colorset 5, "Light Brown", 0x38, 0x47,  0x3A;
		Player.Colorset 6, "Light Red",	0xB0, 0xBF,  0xB2;
		Player.Colorset 7, "Light Blue", 0xC0, 0xCF,  0xC2;

		PortalPlayer.CarryRange 96.0;
	}

	States
	{
		Spawn:
			PLAY A -1;
			Loop;
		See:
			PLAY ABCD 4;
			Loop;
		Missile:
			PLAY E 12;
			Goto Spawn;
		Melee:
			PLAY F 6 BRIGHT;
			Goto Missile;
		Pain:
			PLAY G 4;
			PLAY G 4 A_Pain;
			Goto Spawn;
		Death:
			PLAY H 10;
			PLAY I 10 A_PlayerScream;
			PLAY J 10 A_NoBlocking;
			PLAY KLM 10;
			PLAY N -1;
			Stop;
		XDeath:
			PLAY O 5;
			PLAY P 5 A_XScream;
			PLAY Q 5 A_NoBlocking;
			PLAY RSTUV 5;
			PLAY W -1;
			Stop;
	}

	override void PostBeginPlay()
	{
		actortracer = new("UsePointTracer");
		carrytracer = new("CarryPointTracer");

		Super.PostBeginPlay();

		While (!reflectioncamera) { reflectioncamera = Spawn("MirrorCamera"); }

		if (reflectioncamera)
		{
			TexMan.SetCameraToTexture(reflectioncamera, "PLAYVIEW", 90.0);
			reflectioncamera.master = self;
		}
	}

	override void Tick()
	{
		if (!player)
		{
			Super.Tick();
			return;
		}

		DoInteractions();
		DoFootsteps();
		CheckTouchers();

		for (int i = 0; i < min(touchers.Size(), 64); i++)
		{
			if (touchers[i])
			{
				if (
					Distance3D(touchers[i]) > (Radius + touchers[i].radius) ||
					touchers[i].pos.z + touchers[i].height < pos.z
				) { touchers.Delete(i); }
			}
			else { touchers.Delete(i); touchers.ShrinkToFit(); }
		}

		Line current = CurrentLine();
		if (current && current.alpha > 0)
		{
			for (int i = 0; i < 2; i++)
			{
				Side HitSide = current.sidedef[i];

				if (HitSide)
				{
					TextureID tex = HitSide.GetTexture(Side.mid);

					if (tex && TexMan.GetName(tex) ~== "EMANGRIL")
					{
						if (HitSide.flags & Side.WALLF_WRAP_MIDTEX || current.flags & Line.ML_WRAP_MIDTEX) { ClearPortals(); } // If it's floor-to-ceiling, skip checks
						else
						{
							double yoffset = HitSide.GetTextureYOffset(1);
							Vector2 size = TexMan.GetScaledSize(tex);

							if (current.flags & Line.ML_DONTPEGBOTTOM) // Lower unpegged
							{
								if (pos.z > curSector.floorplane.ZAtPoint(pos.xy) + yoffset - 24.0 && pos.z + height < curSector.floorplane.ZAtPoint(pos.xy) + yoffset + size.y + 24.0)
								{
									ClearPortals();
								}
							}
							else
							{
								if (pos.z > curSector.ceilingplane.ZAtPoint(pos.xy) + yoffset + 24.0 && pos.z + height < curSector.ceilingplane.ZAtPoint(pos.xy) + yoffset - size.y - 24.0)
								{
									ClearPortals();
								}
							}
						}
					}
					else if (tex && TexMan.GetName(tex) ~== "KILLGRIL")
					{
						if (HitSide.flags & Side.WALLF_WRAP_MIDTEX || current.flags & Line.ML_WRAP_MIDTEX) { DamageMobj(null, null, player.health, "Death Grille"); } // If it's floor-to-ceiling, skip checks
						else
						{
							double yoffset = HitSide.GetTextureYOffset(1);
							Vector2 size = TexMan.GetScaledSize(tex);

							if (current.flags & Line.ML_DONTPEGBOTTOM) // Lower unpegged
							{
								if (pos.z > curSector.floorplane.ZAtPoint(pos.xy) + yoffset - 24.0 && pos.z + height < curSector.floorplane.ZAtPoint(pos.xy) + yoffset + size.y + 24.0)
								{
									DamageMobj(null, null, player.health + 25, "Death Grille");
								}
							}
							else
							{
								if (pos.z > curSector.ceilingplane.ZAtPoint(pos.xy) + yoffset + 24.0 && pos.z + height < curSector.ceilingplane.ZAtPoint(pos.xy) + yoffset - size.y - 24.0)
								{
									DamageMobj(null, null, player.health + 25, "Death Grille");
								}
							}
						}
					}
				}
			}
		}
		else { lastline = null; }

		// One-time water entry/exit splashes
		if (waterlevel > 0 && waterstate == 0) { A_StartSound("world/water/enter", 8, 0, 0.1 * abs(vel.z)); }
		else if (waterlevel == 0 && waterstate > 0) { A_StartSound("world/water/exit", 8, 0, 0.1 * abs(vel.z)); }

		// Underwater effect
		//  Note:  Should just be a local sound, but local sounds apparently can't be stopped with A_StopSound, so
		//  world/underwater sound is set up with a 8-16 unit log attenuation in SNDINFO to get a similar effect...
		if (waterlevel >= 3 && waterstate < 3) { A_StartSound("world/underwater", CHAN_5, CHANF_NOPAUSE | CHANF_NOSTOP | CHANF_LOOP, 0.25); }
		else if (waterlevel < 3 && waterstate >= 3) { A_StopSound(CHAN_5); }

		waterstate = waterlevel;

		if (!CurrentPortal || Distance3D(CurrentPortal) > 32.0)
		{
			CurrentPortal = null;
			A_SetSize(Default.Radius, Default.Height * player.crouchfactor, true); // Make sure to reset the size (could have been left small by a PortalSpot in some cases)
		}

		if (!party && (player.cheats & CF_GODMODE2 || player.cheats & CF_GODMODE) && !developer) // Just for fun...
		{
			A_StartSound("world/party", CHAN_AUTO, CHANF_LOCAL);
			
			sparks = Spawn("ConfettiSpawner", pos + (0, 0, 64));
			party = true;

			if (sparks)
			{
				sparks.pitch = 90;
				sparks.A_SetTics(140);
			}
		}

		if (sparks)
		{
			sparks.SetOrigin(pos + (Random(-24, 24), Random(-24, 24), 64), false);
			sparks.angle = angle;
		}

		if (player.health > 0 && player.health < GetMaxHealth(true)) { player.health++; player.mo.health = player.health; }

		double volume = clamp((AirSpeed - 10) / 35.0, 0.0, 1.0);
		A_StartSound("world/whoosh", CHAN_7, CHANF_NOSTOP, volume);
		A_SoundVolume(CHAN_7, volume);

		// Normalize pitch/roll in case we ended up inverted or overflowed
		pitch = Normalize180(pitch);
		roll = Normalize180(roll);

		// Restore roll to neutral automatically over time
		if (roll > 0) { roll = max(roll - 5, 0); }
		else if (roll < 0) { roll = min(roll + 5, 0); }

		if (player.onground) { gravity = Default.gravity; }

		Super.Tick();
	}

	override void MovePlayer ()
	{
		let player = self.player;
		UserCmd cmd = player.cmd;

		// [RH] 180-degree turn overrides all other yaws
		if (player.turnticks)
		{
			player.turnticks--;
			Angle += (180. / TURN180_TICKS);
		}
		else
		{
			Angle += cmd.yaw * (360./65536.);
		}

		player.onground = (pos.z <= floorz) || bOnMobj || bMBFBouncer || (player.cheats & CF_NOCLIP2);

		// killough 10/98:
		//
		// We must apply thrust to the player and bobbing separately, to avoid
		// anomalies. The thrust applied to bobbing is always the same strength on
		// ice, because the player still "works just as hard" to move, while the
		// thrust applied to the movement varies with 'movefactor'.

		if (cmd.forwardmove | cmd.sidemove)
		{
			double forwardmove, sidemove;
			double bobfactor;
			double friction, movefactor;
			double fm, sm;

			[friction, movefactor] = GetFriction();
			bobfactor = friction < ORIG_FRICTION ? movefactor : ORIG_FRICTION_FACTOR;

			if (!player.onground && !bNoGravity && !waterlevel && !climbing)
			{
				// [RH] allow very limited movement if not on ground.
				movefactor *= level.aircontrol;
				bobfactor *= level.aircontrol;
			}

			fm = cmd.forwardmove;
			sm = cmd.sidemove;
			[fm, sm] = TweakSpeeds (fm, sm);
			fm *= Speed / 256;
			sm *= Speed / 256;

			// When crouching, speed and bobbing have to be reduced
			if (CanCrouch() && player.crouchfactor != 1)
			{
				fm *= player.crouchfactor;
				sm *= player.crouchfactor;
				bobfactor *= player.crouchfactor;
			}

			forwardmove = fm * movefactor * (35 / TICRATE);
			sidemove = sm * movefactor * (35 / TICRATE);

			if (forwardmove)
			{
				Bob(Angle, cmd.forwardmove * bobfactor / 256., true);
				ForwardThrust(forwardmove, Angle);
			}
			if (sidemove)
			{
				let a = Angle - 90;
				Bob(a, cmd.sidemove * bobfactor / 256., false);
				Thrust(sidemove, a);
			}

			if (!(player.cheats & CF_PREDICTING) && (forwardmove != 0 || sidemove != 0))
			{
				PlayRunning ();
			}

			if (player.cheats & CF_REVERTPLEASE)
			{
				player.cheats &= ~CF_REVERTPLEASE;
				player.camera = player.mo;
			}
		}
	}

	override void CheckCheats()
	{
		let player = self.player;
		// No-clip cheat
		if ((player.cheats & (CF_NOCLIP | CF_NOCLIP2)) == CF_NOCLIP2)
		{ // No noclip2 without noclip
			player.cheats &= ~CF_NOCLIP2;
		}
		bNoClip = (player.cheats & (CF_NOCLIP | CF_NOCLIP2) || Default.bNoClip);
		if (player.cheats & CF_NOCLIP2)
		{
			bNoGravity = true;
		}
		else if (!climbing && !bFly && !Default.bNoGravity) // Added 'climbing' check
		{
			bNoGravity = false;
		}
	}

	override void PlayerThink()
	{
		let player = self.player;
		UserCmd cmd = player.cmd;
		
		CheckFOV();

		if (player.inventorytics)
		{
			player.inventorytics--;
		}
		CheckCheats();

		if (bJustAttacked)
		{ // Chainsaw/Gauntlets attack auto forward motion
			cmd.yaw = 0;
			cmd.forwardmove = 0xc800/2;
			cmd.sidemove = 0;
			bJustAttacked = false;
		}

		bool totallyfrozen = CheckFrozen();

		// Handle crouching
		CheckCrouch(totallyfrozen);
		CheckMusicChange();

		if (player.playerstate == PST_DEAD)
		{
			DeathThink ();
			return;
		}

		if (player.jumpTics != 0)
		{
			player.jumpTics--;
			if (player.onground && player.jumpTics < -18)
			{
				player.jumpTics = 0;
			}
		}

		if (player.morphTics && !(player.cheats & CF_PREDICTING)) { MorphPlayerThink (); }

		// Crouching moves down while climbing
		if (climbing && cmd.buttons & BT_CROUCH) { vel.z -= 0.95; }

		bool waslanded = player.onground;

		CheckPitch();
		HandleMovement();

		if (level.time > 35 && !waslanded && player.onground && waterlevel < 3)
		{
			String snd = GetStepSound();
			double volume = clamp(airspeed / 40, 0, 4.0);

			stepdelay = 15;
			step = !step;

			if (snd != "") { A_StartSound(snd, step ? 40 : 41, CHANF_OVERLAP, volume, ATTN_STATIC, FRandom(0.95, 1.05)); }

			A_StartSound("player/land", CHAN_AUTO, 0, max(0, airspeed - 8) / 96.0);
		}

		airspeed = vel.length();

		// Only recalculate the view position if you're not climbing or if you are climbing at speed
		// Keeps the float bob effect from being visible to the player
		if (!climbing || abs(vel.length()) > 1.0) { CalcHeight (); }

		// Bobbing while on the ladder is caused by P_ZMovement in p_mobj.cpp and can't be altered (currently lines 3028-3035).  
		// This flag tricks the player actor into only bobbing a tiny bit, but is an awful hack that depends on a quirk in the checks in the internal code.
		// NOCLIP2 gets unset almost immediately after the check is made here, so never actually takes effect.
		// Since this is just cosmetic (you only see it in chasecam or multiplayer), it may be best to comment it out, just in case internal code changes in the future.
//		if (climbing) { player.cheats |= CF_NOCLIP2; }

		if (!(player.cheats & CF_PREDICTING))
		{
			CheckEnvironment();
			player.mo.CheckUse();
			player.mo.CheckUndoMorph();
			// Cycle psprites.
			// Note that after this point the PlayerPawn may have changed due to getting unmorphed so 'self' is no longer safe to use.
			player.mo.TickPSprites();
			// Other Counters
			if (player.damagecount)	player.damagecount--;
			if (player.bonuscount) player.bonuscount--;

			if (player.hazardcount)
			{
				player.hazardcount--;
				if (!(level.time % player.hazardinterval) && player.hazardcount > 16*TICRATE)
					player.mo.DamageMobj (NULL, NULL, 5, player.hazardtype);
			}
			player.mo.CheckPoison();
			player.mo.CheckDegeneration();
			player.mo.CheckAirSupply();
		}
	}

	override void CheckJump()
	{
		let player = self.player;
		// [RH] check for jump
		if (player.cmd.buttons & BT_JUMP)
		{
			if (player.crouchoffset != 0)
			{
				// Jumping while crouching will force an un-crouch but not jump
				player.crouching = 1;
			}
			else if (waterlevel >= 2)
			{
				Vel.Z = 4 * Speed;
			}
			else if (bNoGravity && !climbing)
			{
				Vel.Z = 3.;
			}
			else if (climbing && !player.onground && level.IsJumpingAllowed())
			{
				if (abs(deltaangle(angle, AngleTo(climbing))) > 60)
				{
					if (player.cmd.forwardmove > 0)
					{
						Thrust(Speed / 2, angle);
						Vel.Z = 1.0;
					}
				}
				else
				{
					Vel.Z = 3.;
				}
			}
			else if (level.IsJumpingAllowed() && player.onground && player.jumpTics == 0)
			{
				double jumpvelz = JumpZ * 35 / TICRATE;
				double jumpfac = 0;

				// [BC] If the player has the high jump power, double his jump velocity.
				// (actually, pick the best factors from all active items.)
				for (let p = Inv; p != null; p = p.Inv)
				{
					let pp = PowerHighJump(p);
					if (pp)
					{
						double f = pp.Strength;
						if (f > jumpfac) jumpfac = f;
					}
				}
				if (jumpfac > 0) jumpvelz *= jumpfac;

				Vel.Z += jumpvelz;
				bOnMobj = false;
				player.jumpTics = -1;
				if (!(player.cheats & CF_PREDICTING)) A_StartSound("*jump", CHAN_BODY);
			}
		}
	}

	override void CrouchMove(int direction)
	{
		let player = self.player;
		
		double defaultheight = FullHeight;
		double savedheight = Height;
		double crouchspeed = direction * CROUCHSPEED;
		double oldheight = player.viewheight;

		player.crouchdir = direction;
		player.crouchfactor += crouchspeed;

		maxstepheight = Default.maxstepheight * player.crouchfactor;

		// check whether the move is ok
		Height = defaultheight * player.crouchfactor;

		bool canuncrouch = true;

		for (int i = 0; i < min(touchers.Size(), 64); i++)
		{
			if (touchers[i])
			{
				if (pos.z + defaultheight > touchers[i].pos.z) { canuncrouch = false; }
			}
		}

		if (!TryMove(Pos.XY, false, NULL) || !canuncrouch)
		{
			Height = savedheight;
			if (direction > 0)
			{
				// doesn't fit
				player.crouchfactor -= crouchspeed;
				return;
			}
		}
		Height = savedheight;

		player.crouchfactor = clamp(player.crouchfactor, 0.5, 1.);
		player.viewheight = ViewHeight * player.crouchfactor;
		player.crouchviewdelta = player.viewheight - ViewHeight;

		// Check for eyes going above/below fake floor due to crouching motion.
		CheckFakeFloorTriggers(pos.Z + oldheight, true);
	}

	override bool CanCollideWith(Actor other, bool passive)
	{
		if (
			DragTarget &&
			(
				other == DragTarget || 
				(other.master && other.master == DragTarget)
			) &&
			(
				DragTarget.BlockingLine &&
				!(
					DragTarget.BlockingLine.flags & Line.ML_TWOSIDED &&
					(
						DragTarget.BlockingLine.flags & Line.ML_BLOCKING ||
						DragTarget.BlockingLine.flags & Line.ML_BLOCK_PLAYERS ||
						DragTarget.BlockingLine.flags & Line.ML_BLOCKEVERYTHING
					)
				)
			)
		) { return false; }

		return true;
	}

	void ClearPortals()
	{
		PortalGun gun = PortalGun(FindInventory("PortalGun", true));
	
		if (gun)
		{
			Line current = CurrentLine();

			bool fizzle = false;

			if (gun.portalA) { PortalSpot(gun.portalA).DoDestroy(); gun.portalA.A_StartSound("portal/fizzle", CHAN_AUTO); fizzle = true; }
			if (gun.portalB) { PortalSpot(gun.portalB).DoDestroy(); gun.portalB.A_StartSound("portal/fizzle", CHAN_AUTO); fizzle = true; }

			if (fizzle)
			{
				A_StartSound("portalgun/fizzle", CHAN_AUTO);

				if (gun == player.ReadyWeapon)
				{
					let psp = player.GetPSprite(PSP_WEAPON);					
					psp.SetState(gun.FindState("Shake"));
				}
			}

			lastline = current;
		}

		DropCarried();
	}

	void CheckTouchers()
	{
		BlockThingsIterator it = BlockThingsIterator.Create(self, 128);
		Actor mo;

		while (it.Next() && (mo = it.thing))
		{
			if (mo.bSolid && !mo.bNoInteraction) { Touch(mo); }
		}
	}

	override void Touch(Actor toucher)
	{
		if (Distance2D(toucher) > Radius + toucher.Radius) { return; }
		if (toucher == self || toucher == toucher.master) { return; }
		if (toucher.pos.z > pos.z + height + 32.0 || toucher.pos.z <= pos.z) { return; }
		if (touchers.Find(toucher) == touchers.Size()) { touchers.Push(toucher); }
	}

	void DropCarried()
	{
		bTeleport = false;
		carryblocked = false;

		if (!DragTarget) { return; }

/*
		if (DragTarget.CanCollideWith(self, true))
		{
			A_StartSound("*usefail", CHAN_AUTO, CHANF_LOCAL);
			return;
		}
*/

		if (!DragTarget.TryMove(DragTarget.pos.xy, true))
		{
			A_StartSound("*usefail", CHAN_AUTO, CHANF_LOCAL);
			return;
		}

		A_StartSound("object/drop", CHAN_AUTO);

		DragTarget.angle = angle;
		DragTarget.vel = vel * DragTarget.pushfactor + dragvel; // + (RotateVector((1, 0), angle), -1);
		DragTarget.bNoGravity = DragTarget.Default.bNoGravity;
		DragTarget.bNoInteraction = DragTarget.Default.bNoInteraction;
		DragTarget.A_ChangeLinkFlags(0);
		DragTarget.master = null;
		DragTarget = null;

		UseRange = carryrange;

		DoWeaponDrop();
	}

	void DoInteractions()
	{
		Actor AimActor;
		Actor portalsource;

		DoTrace(self, angle, 1024, pitch, 0, player.viewheight, actortracer);

		AimActor = actortracer.Results.HitActor;

		if (AimActor && AimActor is "PlayerPawn" || AimActor is "PortalSpot") { AimActor = null; }

		if (!AimActor && currentportal && PortalSpot(currentportal).pair)
		{
			double dist = Distance2D(currentportal);

			if (dist < carryrange && abs(deltaangle(angle, AngleTo(currentportal))) < 75)
			{
				portalsource = PortalSpot(currentportal).pair;
				DoTrace(portalsource, angle - currentportal.angle + portalsource.angle + 180, carryrange * 1.5 - dist, pitch, 0, (player.viewheight - 32.0) * sin(portalsource.pitch), actortracer);
			}
		}

		AimActor = actortracer.Results.HitActor;
		AimTexture = actortracer.Results.HitTexture;

		if (AimTexture)
		{
				if (Texman.GetName(AimTexture).Left(5) ~== "GLASS" || Texman.GetName(AimTexture).Left(5) ~== "PIPE")
				{
//					reflectioncamera.SetOrigin(actortracer.Results.HitPos - AngleToVector(AngleTo(reflectioncamera), 0.5), false);
					MirrorCamera(reflectioncamera).linedef = actortracer.Results.HitLine;
				}
		}

		bool inportal = bTeleport || CurrentPortal;

		if (player.usedown)
		{
			if (!useheld)
			{
				if (!DragTarget)
				{
					if (AimActor && Distance3d(AimActor) < carryrange) { AimActor.Used(self); }

					if (
						AimActor && !AimActor.bDormant &&
						(Distance3D(AimActor) < carryrange || portalsource)
					)
					{
						if (AimActor.bPushable)
						{
							A_StartSound("object/pickup", CHAN_AUTO);

							DragTarget = AimActor;
							DragTarget.master = self;
							DragTarget.bNoGravity = true;
//							DragTarget.bNoInteraction = true;
							DragTarget.bInterpolateAngles = true;

							UseRange = 0;

							DoWeaponCarry();
						}
						else if (Inventory(AimActor))
						{
							A_StartSound(Inventory(AimActor).PickupSound, CHAN_AUTO);

							AimActor.Touch(self);
						}
					}
				}
				else if (!inportal)
				{
					DropCarried();
				}
				useheld = true;
			}
		}
		else
		{
			useheld = false;
		}

		if (DragTarget)
		{
			player.cmd.buttons |= BT_USE;

			Vector3 oldpos = DragTarget.pos;

			DragTarget.bNoInteraction = inportal;
			DragTarget.A_ChangeLinkFlags(0);

			double range = max(carryrange - 32.0, radius + DragTarget.radius * 1.5);
			Vector3 dragtargetpos = pos + RotateVector((cos(max(pitch, -20)) * range - DragTarget.Radius * 1.4, 0), angle) + (0, 0, player.viewheight - sin(pitch) * range - DragTarget.Radius * 1.4);

			let carrytarget = CarryActor(DragTarget);
			if (carrytarget) { dragtargetpos.z += carrytarget.zoffset; }

			if (bNoClip || DragTarget.bNoInteraction)
			{
				DragTarget.angle = angle;
				DragTarget.vel = vel;

				DragTarget.SetOrigin(dragtargetpos, true);
			}
			else
			{
				double floorheight = max(DragTarget.curSector.NextLowestFloorAt(DragTarget.pos.x, DragTarget.pos.y, DragTarget.pos.z), DragTarget.floorz);
				if (carrytarget) { floorheight += carrytarget.zoffset; }

				Vector3 tracedir = (cos(angle) * cos(max(pitch, -20)), sin(angle) * cos(max(pitch, -20)), -sin(max(pitch, -20)));
				carrytracer.skipactor = self;
				carrytracer.Trace(pos + (0, 0, player.viewheight), CurSector, tracedir, range, 0 );

				if (DragTarget.BlockingLine) { carryblocked = CheckCarryBlockingLine(DragTarget.BlockingLine); }

				if (carrytracer.Results.HitType == TRACE_HitWall)
				{
					if (carrytracer.Results.HitLine && carrytracer.Results.HitLine == DragTarget.BlockingLine)
					{
						if (!bTeleport && Distance2D(DragTarget) > range)
						{
							DropCarried();
							return;
						}
					}
					else if (
						carrytracer.Results.Distance < range &&
						carrytracer.Results.HitType == TRACE_HitWall && 
						carrytracer.Results.HitLine &&
						(
							carrytracer.Results.HitLine.flags & Line.ML_TWOSIDED &&
							!(
								carrytracer.Results.HitLine.flags & Line.ML_BLOCKING ||
								carrytracer.Results.HitLine.flags & Line.ML_BLOCKEVERYTHING
							)
						)
					)
					{
						// Continue...
					}
					else
					{
						dragtargetpos = carrytracer.Results.HitPos - RotateVector((-DragTarget.Radius * 1.4, 0), angle + 180) + (0, 0, -12);
					}
					
					if ((level.Vec3Diff(pos + (0, 0, 32), dragtargetpos)).length() < DragTarget.Radius * 1.4)
					{
						dragtargetpos.xy = DragTarget.pos.xy;
					}
				}

				dragtargetpos.z = max(dragtargetpos.z, floorheight);
				if (carryblocked) { dragtargetpos.xy = DragTarget.pos.xy; }

				if (
					bTeleport || 
					(
						DragTarget.pos != dragtargetpos && 
						level.IsPointInLevel(dragtargetpos) &&
						DragTarget.CheckMove(dragtargetpos.xy, PCM_NOACTORS)
					)
				)
				{
					DragTarget.SetOrigin(dragtargetpos, !bTeleport);
				}

				DragTarget.angle = angle;
				DragTarget.vel = vel;

				if (!bTeleport)
				{
					dragvel = (DragTarget.pos - oldpos + (player.cmd.yaw * cos(angle + 90), player.cmd.yaw * sin(angle + 90), player.cmd.pitch)) / (5 * DragTarget.Mass);
					if (!bNoClip && Distance3D(DragTarget) > (range + (!!carrytarget ? carrytarget.zoffset : 0)) * 1.75) { DropCarried(); }
				}
			}
		}

		bTeleport = false;
	}

	bool CheckCarryBlockingLine(Line linedef)
	{
		if (!linedef) { return false; }

		bool ret = false;

		if (linedef.sidedef[0]) { ret = CheckCarryBlockingTexture(linedef.sidedef[0].GetTexture(Side.mid)); }
		if (!ret && linedef.sidedef[1]) { ret = CheckCarryBlockingTexture(linedef.sidedef[1].GetTexture(Side.mid)); }

		return ret;
	}

	bool CheckCarryBlockingTexture(TextureID texture)
	{
		if (!texture) { return false; }

		String tex = TexMan.GetName(texture);

		if (tex.Left(5) ~== "GLASS" || tex.Left(5) ~== "GRATE" || tex ~== "KILLGRIL" || tex ~== "CHAINLNK")
		{
			return true;
		}

		return false;
	}

	void DoFootSteps()
	{
		double speedxy = vel.xy.length();

		double floorheight = max(floorz, curSector.NextLowestFloorAt(pos.x, pos.y, pos.z));

		if ((!bOnMobj && !waterlevel && pos.z > floorheight) || waterlevel >= 3) { stepdelay = 0; }
		else if (stepdelay > 0)
		{
			int currentdelay = int(clamp(35.0 - (3 * speedxy), 15, 35));

			if (stepdelay > currentdelay) { stepdelay = currentdelay / 2; }
			stepdelay = max(stepdelay - 1, 0);
		}
		else
		{
			double lookspeed = abs((player.cmd.yaw * cos(angle + 90), player.cmd.yaw * sin(angle + 90)).length()) / 1000;
			double measure = int(speedxy) ? speedxy : lookspeed;

			if (measure && (bOnMobj || pos.z <= floorheight || (waterlevel > 0 && waterlevel < 3)))
			{
				String snd = GetStepSound();

				double volume = clamp(measure / 80, 0, 4.0);

				if (int(oldvel.xy.length()) == 0) { stepdelay = 15; }
				else { stepdelay = int(clamp(35.0 - (3 * measure), 15, 35)); }

				step = !step;

				if (snd != "") { A_StartSound(snd, step ? 40 : 41, CHANF_OVERLAP, volume, ATTN_STATIC, FRandom(0.95, 1.05)); }
			}
		}

		oldvel = vel;
	}

	String TextureName(TextureID input)
	{
		if (!input) { return ""; }

		// See what texture we are checking
		String texname = TexMan.GetName(input);

		if (texname.IndexOf(".") >= 0) // If it's a long filename
		{
			// Strip the texture name down to only the filename (basically the old-style texture name)
			int start = texname.RightIndexOf("/") + 1;
			texname = texname.Mid(start, texname.RightIndexOf(".") - start);
		}

		return texname;
	}

	String GetStepSound()
	{
		if (waterlevel == 1) { return "footsteps/puddle"; }
		else if (waterlevel == 2) { return "footsteps/wade"; }

		if (bOnMobj)
		{
			Actor onmo = Utilities.FindOnMobj(self);

			if (onmo)
			{
				if (onmo is "BlockBase")
				{
					while(onmo.master) { onmo = onmo.master; }
				}

				if (onmo is "PortalActor")
				{
					String snd = PortalActor(onmo).stepsound;
					if (snd.length()) { return snd; }
				}

				// For actor-specifics, as needed...  Most actors handled by the PortalActorstepsound property above now
				Switch(onmo.GetClassName())
				{
					case 'BridgeBeam':
						return "footsteps/glass";
					default:
						return "footsteps/default";
						break;
				}
			}
		}

		Switch(Name(TextureName(floorpic)))
		{
			case 'WALL1x1':
			case 'WALL2x1':
			case 'WALL2x2':
			case 'WALL4x4':
			case 'WALL1x1S':
			case 'WALL2x1S':
			case 'WALL2x2S':
			case 'WALL4x4S':
			case 'WALL1x1D':
			case 'WALL2x1D':
			case 'WALL2x2D':
			case 'WALL4x4D':
			case 'WALLTX1':
			case 'WALLTX2':
			case 'LITB1x1':
			case 'LITB2x1':
			case 'LITB2x2':
			case 'LITBW1x1':
			case 'LITBW2x1':
			case 'FLOOR':		
			case 'FLOORCON':
				return "footsteps/blacktile";
				break;
			case 'PORT1x1':
			case 'PORT2x1':
			case 'PORT2x2':
			case 'PORT4x1':
			case 'PORT4x4':
			case 'PORTTX1':
			case 'PORTTX2':
			case 'LITW1x1':
			case 'LITW2x1':
			case 'LITW2x2':
			case 'LITWW1x1':
			case 'LITWW2x1':
			case 'CARPET':
			case 'CARPET2':
				return "footsteps/whitetile";
				break;
			case 'GRATE':
			case 'GRATE2':
			case 'FLOORMET':
				return "footsteps/grate";
			case 'GLASS':
			case 'GLASSTRA':
			case 'GLASS2':
			case 'GLASS3':
				return "footsteps/glass";
			default:
				return "footsteps/default";
				break;
		}

		return "";
	}

	void DoTrace(Actor origin, double angle, double dist, double pitch, int flags, double zoffset, UsePointTracer thistracer)
	{
		if (!origin) { origin = self; }

		thistracer.skipspecies = origin.species;
		thistracer.skipactor = origin;
		Vector3 tracedir = (cos(angle) * cos(pitch), sin(angle) * cos(pitch), -sin(pitch));
		thistracer.Trace(origin.pos + (0, 0, zoffset), origin.CurSector, tracedir, dist, 0);
	}

	Line CurrentLine()
	{
		// Find the line that this actor's centerpoint is closest to
		Line linedef;
		double dist;

		BlockLinesIterator it = BlockLinesIterator.Create(self);

		While (it.Next())
		{
			Line current = it.curline;

			// Discard lines that definitely don't cross the actor's center point
			if (
				(current.v1.p.x > pos.x + radius && current.v2.p.x > pos.x + radius) ||
				(current.v1.p.x < pos.x - radius && current.v2.p.x < pos.x - radius) ||
				(current.v1.p.y > pos.y + radius && current.v2.p.y > pos.y + radius) ||
				(current.v1.p.y < pos.y - radius && current.v2.p.y < pos.y - radius) 
			) { continue; }

			// Find the line that is closest based on proximity to end vertices
			double curdist = (current.v1.p - pos.xy + current.v2.p - pos.xy).Length();
			if (!linedef || curdist <= dist)
			{
				linedef = current;
				dist = curdist;
			}
		}

		return linedef;
	}

	virtual void DoWeaponCarry()
	{
		let player = self.player;
		
		PortalGun weapn = PortalGun(player.ReadyWeapon);
		if (!weapn) { return; }

		player.SetPsprite(PSP_WEAPON, weapn.GetCarryState());
	}

	virtual void DoWeaponDrop()
	{
		let player = self.player;
		
		PortalGun weapn = PortalGun(player.ReadyWeapon);
		if (!weapn) { return; }

		player.SetPsprite(PSP_WEAPON, weapn.GetReadyState());
	}
}

class UseMarker : Actor
{
	Default
	{
		Radius 1;
		Height 1;
		+NOINTERACTION
	}

	States
	{
		Spawn:
			AMRK A 35;
			Stop;
	}
}

class MirrorCamera : SecurityCamera
{
	Line linedef;
	double lineangle;

	override void Tick()
	{
		Super.Tick();

		if (!master || !PlayerPawn(master)) { Destroy(); }

		if (linedef)
		{
			if (!linedef.delta.x)
			{
				lineangle = 0;
			}
			else if (!linedef.delta.y)
			{
				lineangle = 90;
			}
			else { lineangle = (atan(linedef.delta.y / linedef.delta.x) + 270) % 360; }

			if (abs(deltaangle(lineangle, AngleTo(master))) > 90) { lineangle += 180; }

			SetOrigin((linedef.v1.p + linedef.delta / 2, master.pos.z + PlayerPawn(master).viewheight), true);
		}

		if (master && master.player && master.player.camera)
		{
			angle = lineangle; // - AngleTo(master);
		}
	}

	double PitchTo(Actor mo, Actor source = null)
	{
		if (source == null) { source = self; }

		double distxy = max(source.Distance2D(mo), 1);
		double distz = source.pos.z - mo.pos.z;

		return atan(distz / distxy);
	}
}