class PortalSpot : Actor
{
	PortalSpot pair;
	Actor camera, ring;
	Array<Actor> Activators;
	Array<Actor> BeamSources;
	String camtex;
	Vector3 shotpos, snappos, finalpos, camerapos;
	bool open, forcelocation;
	double spawnfloor, spawnceiling, slopeangle, spawnangle, movedist, lineangle;
	PortalFindHitPointTracer hittracer;
	CarryPointTracer blocktracer;
	Line linedef;
	int offset;
	bool blocked, noplayers;
	Vector3 forward, right, up;
	Portal_Matrix worldtransform, transform;

	Default
	{
		+SPECIAL
		+NOGRAVITY
		+INVISIBLE
		-SOLID
		-SHOOTABLE
		+BRIGHT
		+MASKROTATION
		VisibleAngles -90, 90;
		VisiblePitch 180, -180;
		Radius 1;
		Height 1;
		MaxDropOffHeight 64;
	}

	States
	{
		Spawn:
			POR0 A 8;
			"####" # 0 {
				open = true;
				A_StartSound("portal/open", CHAN_AUTO);
			}
		Open:
			"####" # 1;	
			Loop;
		OtherPlayers:
			POR1 A 0; // Players 1-8
			POR2 A 0;
			POR3 A 0;
			POR4 A 0;
			POR5 A 0;
			POR6 A 0;
			POR7 A 0;
			POR8 A 0;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER + 1);

		A_SetSize(64.0, -1, false); // Set the range for where the portals start finding activators

		offset = Random(0, 35);

		Super.BeginPlay();
	}

	override void PostBeginPlay()
	{
		hittracer = new("PortalFindHitPointTracer");
		blocktracer = new("CarryPointTracer");

		movedist = 13.0;

		if (pitch == 0)
		{
			if (pos.z < floorz + 32) { SetOrigin((pos.xy, floorz + 32), false); }
			if (pos.z > ceilingz - 32) { SetOrigin((pos.xy, ceilingz - 32), false); }
		}
		else
		{
			VisibleStartAngle = -180;
			VisibleEndAngle = 180;
		}

		camerapos = pos + RotateVector3((0.5, 0.0, players[consoleplayer].viewheight - 32.0), angle, pitch, roll);
		camera = Spawn("PortalCamera", camerapos);
		if (camera)
		{
			camera.master = self;
			camera.angle = angle;
			camera.pitch = pitch;
		}

		SpawnPoint = pos;
		spawnfloor = floorz;
		spawnceiling = ceilingz;
		spawnangle = angle;

		CheckSpawn();

		Vector3 tracedir = (cos(angle) * cos(pitch), sin(angle) * cos(pitch), -sin(pitch));
		blocktracer.Trace(pos + (0, 0, height / 2), CurSector, tracedir, 16.0, 0 );

		if (blocktracer.Results.HitType)
		{
			blocked = true;

			if (blocktracer.Results.HitType == TRACE_HitActor && blocktracer.Results.HitActor is "CarryActor" && !(blocktracer.Results.HitActor.master is "PlayerPawn")) { noplayers = false; }
			else { noplayers = true; }
		}

		forward = tracedir.Unit();
		right = forward cross (0, 0, 1);
		up = right cross forward;

		worldtransform = Portal_Matrix.createTRSEuler(pos, angle, pitch, roll, (1, 1, 1));

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		Super.Tick();

		if (!ring)
		{
			ring = Spawn("PortalRing", pos);
			if (ring)
			{
				ring.master = self;
				ring.angle = angle;
				ring.pitch = pitch;
				ring.roll = roll;
				ring.frame = frame;
			}
		}

		if (!StaticPortalSpot(self)) { OverlayHandler.Add(ring, "Portal", 0, ring.fillcolor, !CheckSight(players[consoleplayer].camera, SF_SEEPASTBLOCKEVERYTHING | SF_IGNOREWATERBOUNDARY | SF_IGNOREVISIBILITY | SF_SEEPASTSHOOTABLELINES) ? 0.5 : 0.0, 1); }

		if (int(lineangle) != GetLineAngle()) { DoDestroy(); }

		if (IsFrozen()) { return; }

		if (pair && pair != self && open && pair.open && ring)
		{
			bInvisible = false;

			if (finalpos == (0, 0, 0)) { finalpos = pos; }
			SetOrigin(finalpos, false);

			transform = pair.worldtransform.multiplyMatrix(Portal_Matrix.matrixInverseTR(worldtransform));

			if (pair.camera)
			{
				double camfov = 60;

				let aimpoint = players[consoleplayer].camera;

				if (aimpoint)
				{
					// Portal_Matrix view = Portal_Matrix.fromEulerAngles(
					// 	angleTo(aimpoint, true),
					// 	-PitchTo(aimpoint, self, -(32.0 + (players[consoleplayer].viewheight - players[consoleplayer].mo.viewheight))),
					// 	deltaangle(roll, aimpoint.roll)
					// );
					// Portal_Matrix pairview = view.multiplyMatrix(transform);

					Portal_Matrix view = Portal_Matrix.fromEulerAngles(
						aimpoint.angleTo(self, true),
						-PitchTo(self, aimpoint, 32.0 + (players[consoleplayer].viewheight - players[consoleplayer].mo.viewheight)),
						deltaangle(aimpoint.roll, roll)
						);
					Portal_Matrix pairview = transform.multiplyMatrix(view);
					Vector3 viewoffset = -RotateVector3(forward, -angle, 0, 0) * 180;
					Portal_Matrix reverse = Portal_Matrix.fromEulerAngles(viewoffset.x, viewoffset.y, viewoffset.z);
					pairview = reverse.multiplyMatrix(pairview);

					// camfov = camfov + 30 / clamp(Distance2D(aimpoint) / 32, 1, 60);

					// Portal_Matrix view = Portal_Matrix.fromEulerAngles(
					// 	aimpoint.angleTo(self, true),
					// 	//  + deltaangle(180 + angle, aimpoint.angle), 
					// 	// angle + deltaangle(aimpoint.angleTo(self, true), aimpoint.angle),
					// 	// 180 + angle,
					// 	-PitchTo(self, aimpoint, 32.0 + (players[consoleplayer].viewheight - players[consoleplayer].mo.viewheight)),
					// 	aimpoint.roll - roll
					// 	);
					// Portal_Matrix newview = transform.multiplyMatrix(view);
					// Vector3 viewoffset = -RotateVector3(forward, -angle, 0, 0);
					// Portal_Matrix reverse = Portal_Matrix.fromEulerAngles(viewoffset.x * 180, viewoffset.y * 180, viewoffset.z * 180);
					// newview = reverse.multiplyMatrix(newview);

					double a, p, r;
					[a, p, r] = pairview.rotationToEulerAngles();

					// Vector2 offset = RotateVector((1, 0), deltaangle(a, pair.angle));
					// Vector2 zoffset = RotateVector((1, 0), deltaangle(-p, pair.pitch));

					// camfov = camfov + abs(30 * offset.y);

					pair.camera.angle = a;
					pair.camera.pitch = -p;
					// pair.camera.angle = pair.angle - offset.y * 90.0;
					// pair.camera.pitch = pair.pitch - zoffset.y * 45.0;
					pair.camera.roll = r;

					// pair.camera.SetOrigin(pair.camerapos + (RotateVector(-offset * 16.0, pair.angle), 0), true);
				}
				else
				{
					pair.camera.angle = pair.angle;
					pair.camera.pitch = pair.pitch;
					pair.camera.roll = pair.roll;
				}

				TexMan.SetCameraToTexture(pair.camera, pair.camtex, camfov);
			}

			if ((level.time + offset) % 10 == 0) { CheckOtherActivators(); }

			for (int i = 0; i < Activators.Size(); i++)
			{
				if (Activators[i] && Activators[i] is "HitMarker")
				{
					if (Distance3D(Activators[i]) > 32.0)
					{
						if (Activators[i].Alternative) { Activators[i].Alternative.Destroy(); }
						Activators.Delete(i);
						continue;
					}

					if (!Activators[i].Alternative && Activators.Size() < 8)
					{
						if (Activators[i] is "HitMarker") { Activators[i].Alternative = Spawn(HitMarker(Activators[i]).spot, Activators[i].pos); }

						if (Activators[i].Alternative)
						{
							Activators[i].Alternative.angle = Activators[i].angle;
							Activators[i].Alternative.pitch = Activators[i].pitch;
							Activators[i].Alternative.roll = Activators[i].roll;
							Activators[i].Alternative.master = pair;
							Activators[i].Alternative.SetStateLabel("Active");
						}
					}

					if (Activators[i].Alternative && Activators[i].Alternative.pos == Activators[i].pos)
					{
						DoMove(Activators[i].Alternative, false);
					}
				}
				else if (Activators[i] && !Activators[i].bNoInteraction && !Activators[i].bNoClip)
				{
					double dist = Distance2D(Activators[i]);
					double disty = PlaneDist(Activators[i], y:true);

					if (Activators[i].pos.z > Activators[i].curSector.NextLowestFloorAt(Activators[i].pos.x, Activators[i].pos.y, Activators[i].pos.z))
					{
						if (pitch && pitch % 90 == 0 && dist < 128)
						{
							Vector2 pull = AngleToVector(Activators[i].AngleTo(self), 0.1 * dist / 128);

							Activators[i].vel += pull;
						}
					}

					if (dist > 64.0/* || (Activators[i].master && Activators[i].master is "PlayerPawn")*/) { Activators.Delete(i); continue; }

					double mintest = max(Activators[i].vel.length() + Activators[i].Default.Radius * 1.4, movedist);

					if (Activators[i] is "PortalPlayer" && Activators[i].player && Activators[i].player.camera)
					{
						if (Distance2D(Activators[i]) < 32.0) { PortalPlayer(Activators[i]).CurrentPortal = self; }
					}

					bool inportalbounds = 
							(!pitch && pos.z - 40.0 <= Activators[i].pos.z && pos.z + 40.0 >= Activators[i].pos.z + Activators[i].height && disty <= 14.0) ||
							(pitch != 0 && Distance3D(Activators[i]) <= movedist + (2 * movedist) * sin(abs(pitch)));

					if (inportalbounds) { Activators[i].A_SetSize(clamp(dist - 8, 1, Activators[i].Default.Radius), -1, true); }
					else { Activators[i].A_SetSize(Activators[i].Default.Radius, Activators[i].Default.Height, true); }

					if (inportalbounds && dist <= mintest)
					{
						if (!(Activators[i].master is "PlayerPawn") && (Activators[i].vel.length() > 0 || pitch != 0 || Activators[i].master is "PlayerPawn"))
						{
							A_StartSound(frame ? "portal/enter2" : "portal/enter1", CHAN_AUTO);

							DoMove(Activators[i]);
							if (Activators[i].Alternative) { Activators[i].Alternative.Destroy(); }
						}
					}
				}
			}

			if (pair && pair.blocked) { noplayers = true; }
			else if (!blocked) { noplayers = false; }
		}
		else
		{
			bInvisible = true;

			if (pair == self) // Ready to destroy
			{
				if (ring)
				{
					if (ring.scale.x > 0) { ring.scale.x = max(ring.scale.x - 0.3, 0); }
					if (ring.scale.y > 0) { ring.scale.y = max(ring.scale.y - 0.3, 0); }

					if (ring.scale.x == 0 && ring.scale.y == 0) { A_StartSound("portal/close", CHAN_AUTO); Destroy(); }
				}

				for (int i = 0; i < Activators.Size(); i++)
				{
					if (Activators[i] && Activators[i].Alternative)
					{
						Activators[i].Alternative.Destroy();
					}
				}
			}
		}
	}

	override void Touch(Actor toucher)
	{
		if (noplayers) { return; }

		if (Activators.Find(toucher) == Activators.Size()) { Activators.Push(toucher); }
	}

	void DoMove(Actor toucher, bool sound = true)
	{
		double zoffset;

		if (toucher.player)
		{
			toucher.player.camera.ClearInterpolation();
			if (ring) { toucher.A_SetBlend(ring.fillcolor, 0.5, 15); } // Flash the screen slightly to cover the transition

			toucher.bTeleport = true;
		}

		if (toucher.bMissile) // Missiles don't actually retain pitch for some reason?
		{
			double distxy = max(toucher.vel.xy.length(), 0.0001);
			double distz = toucher.vel.z;

			toucher.pitch = -atan(distz / distxy);
		}

		Vector3 neworigin = transform.multiplyVector3(toucher.pos).asVector3();
		neworigin = neworigin + pair.forward * toucher.radius * 1.4;

		Portal_Matrix view = Portal_Matrix.fromEulerAngles(toucher.angle, -toucher.pitch, toucher.roll);
		Portal_Matrix newview = transform.multiplyMatrix(view);
		Vector3 viewoffset = -RotateVector3(forward, -angle) * 180;
		Portal_Matrix reverse = Portal_Matrix.fromEulerAngles(viewoffset.x, viewoffset.y, viewoffset.z);
		newview = reverse.multiplyMatrix(newview);

		double a, p, r;
		[a, p, r] = newview.rotationToEulerAngles();

		if (toucher.vel.length())
		{
			toucher.vel = RotateVector3(toucher.vel, a - toucher.angle, -p - toucher.pitch, r - toucher.roll);
			if (toucher.vel.length() < 16.0) { toucher.vel *= 1.05; }
		}

		toucher.angle = a;
		toucher.pitch = -p;
		toucher.roll = r;

		if (!toucher.CheckMove(neworigin.xy)) // If the move would fail for some reason...
		{
			if (abs(pair.pitch) > 45) { neworigin = pair.pos + pair.forward * toucher.radius * 1.4; } // Center anything moving out of a flat plane portal to minimize risk of outside-the-map spawns
		}

		if (pos != neworigin) { toucher.SetOrigin(neworigin, false); }

		if (sound) { pair.A_StartSound(pair.frame ? "portal/exit2" : "portal/exit1", CHAN_AUTO); }
	}

	Vector3 RotateVector3(Vector3 input, double yaw, double pitch = 0, double roll = 0)
	{
		// Adapted from https://stackoverflow.com/questions/34050929/3d-point-rotation-algorithm
		Vector3 output;

		double cosa = cos(yaw);
		double sina = sin(yaw);

		double cosb = cos(pitch);
		double sinb = sin(pitch);

		double cosc = cos(roll);
		double sinc = sin(roll);

		double Axx = cosa * cosb;
		double Axy = cosa * sinb * sinc - sina * cosc;
		double Axz = cosa * sinb * cosc + sina * sinc;

		double Ayx = sina * cosb;
		double Ayy = sina * sinb * sinc + cosa * cosc;
		double Ayz = sina * sinb * cosc - cosa * sinc;

		double Azx = -sinb;
		double Azy = cosb * sinc;
		double Azz = cosb * cosc;

		output.x = Axx * input.x + Axy * input.y + Axz * input.z;
		output.y = Ayx * input.x + Ayy * input.y + Ayz * input.z;
		output.z = Azx * input.x + Azy * input.y + Azz * input.z;

		return output;
	}

	double PlaneDist(Actor source, Actor dest = null, bool y = false)
	{
		if (!dest) { dest = self; }

		Vector2 xydist = source.pos.xy - dest.pos.xy;
		xydist = RotateVector(xydist, -source.angle);

		if (y) { return abs(xydist.y); }

		return abs(xydist.x);
	}

	static const double offsets[] = {
						0, 0, 0, 
						0, 0, 15.0, 
						0, 0, -15.0, 
						0, 7, 0, 
						0, -7, 0,
						0, 0, 30.0, 
						0, 0, -30.0, 
						0, 14, 0, 
						0, -14, 0
					};

	virtual bool CheckValidity()
	{
		if (!GetCVar("g_allportalsurfaces") && !forcelocation)
		{
			Actor spot;

			for (int i = 0; i < 27; i += 3) // Check specific coordinates around the portal to make sure they're on a portalable surface
			{
				spot = DoTrace(self, angle, 8, pitch + 180, (offsets[i], offsets[i + 1], offsets[i + 2]), hittracer); // Fire a tracer

				if (!level.PointInSector(spot.pos.xy)) { return false; } // Make sure the spot is inside the map

				if (!CheckTextureName(hittracer.Results.HitTexture, "PORT") && !CheckTextureName(hittracer.Results.HitTexture, "LITW")) { return false; } // Make sure the texture is a portal-able one
			}
		}

		SetupPortal();

		if ( // Make sure you don't overlap with your own other portal (or a static portal)
			pair && 
			angle == pair.angle &&
			abs(pos.z - pair.pos.z) < 64.0 &&
			Distance2D(pair) < 32.0
		) { return false; }

		return true;
	}

	void SetupPortal()
	{
		if (master)
		{
			PortalGun gun = PortalGun(master.FindInventory("PortalGun", true));

			if (gun)
			{
				if (frame)
				{
					if (gun.portalB) { PortalSpot(gun.portalB).DoDestroy(); }
					gun.portalB = self;

					if (gun.portalA)
					{
						PortalSpot(gun.portalA).pair = self;
						pair = gun.portalA;
					}
				}
				else
				{
					if (gun.portalA) { PortalSpot(gun.portalA).DoDestroy(); }
					gun.portalA = self;

					if (!PortalSpot(gun.portalA).pair || !(PortalSpot(gun.portalA).pair is "StaticPortalSpot"))
					{
						PortalSpot(gun.portalA).pair = gun.portalB;
					}

					if (gun.portalB)
					{
						PortalSpot(gun.portalB).pair = self;
						pair = gun.portalB;
					}
				}
			}
		}
	}

	bool Reposition()
	{
		int oldframe = frame;

		SetState(SpawnState);

		frame = oldframe;

		int position = 1;
		int maxposition = 7;

		Vector3 startpos = pos;

		While (linedef && position <= maxposition && !waterlevel)
		{
			Vector3 newpos = startpos;

			if (pitch % 180 == 0)
			{
				switch (position)
				{
					case 1: // Use newpos as passed in
						break;
					case 2:
						newpos.x -= 16.0 * sin(angle);
						newpos.y -= 16.0 * cos(angle);
						break;
					case 3:
						newpos.x += 16.0 * sin(angle);
						newpos.y += 16.0 * cos(angle);
						break;
					case 4:
						newpos.z -= 32.0;
						break;
					case 5:
						newpos.z += 32.0;
						position = maxposition; // Skip to the end of checking...
						break;
					default:
						break;
				}

				if (newpos.z < spawnfloor + 32) { newpos.z = spawnfloor + 32.0; }
				else if (newpos.z > spawnceiling - 32) { newpos.z = spawnceiling - 32.0; }
			}
			else if (pitch % 90 == 0)
			{
				switch (position)
				{
					case 1: // Use newpos as passed in
						break;
					case 2:
						newpos.x -= 16.0 * sin(angle);
						newpos.y -= 16.0 * cos(angle);
						break;
					case 3:
						newpos.x += 16.0 * sin(angle);
						newpos.y += 16.0 * cos(angle);
						break;
					case 4:
						newpos.x -= 24.0 * sin(angle);
						newpos.y -= 24.0 * cos(angle);
						break;
					case 5:
						newpos.x += 24.0 * sin(angle);
						newpos.y += 24.0 * cos(angle);
						break;
					case 6:
						newpos.x -= 32.0 * sin(angle);
						newpos.y -= 32.0 * cos(angle);
						break;
					case 7:
						newpos.x += 32.0 * sin(angle);
						newpos.y += 32.0 * cos(angle);
						break;
					default:
						break;
				}
			}
			else // Sloped
			{
				newpos.z = SpawnPoint.z;

				switch (position)
				{
					case 1: // Use newpos as passed in
						break;
					case 2:
						newpos.x -= 16.0 * cos(angle) * cos(pitch);
						newpos.y -= 16.0 * sin(angle) * cos(pitch);
						newpos.z -= 16.0 * sin(pitch);
						break;
					case 3:
						newpos.x += 16.0 * cos(angle) * cos(pitch);
						newpos.y += 16.0 * sin(angle) * cos(pitch);
						newpos.z += 16.0 * sin(pitch);
						break;
					case 4:
						newpos.x -= 24.0 * cos(angle) * cos(pitch);
						newpos.y -= 24.0 * sin(angle) * cos(pitch);
						newpos.z -= 24.0 * sin(pitch);
						break;
					case 5:
						newpos.x += 24.0 * cos(angle) * cos(pitch);
						newpos.y += 24.0 * sin(angle) * cos(pitch);
						newpos.z += 24.0 * sin(pitch);
						break;
					case 6:
						newpos.x -= 32.0 * cos(angle) * cos(pitch);
						newpos.y -= 32.0 * sin(angle) * cos(pitch);
						newpos.z -= 32.0 * sin(pitch);
						break;
					case 7:
						newpos.x += 32.0 * cos(angle) * cos(pitch);
						newpos.y += 32.0 * sin(angle) * cos(pitch);
						newpos.z += 32.0 * sin(pitch);
						break;
					default:
						break;
				}
			}

			SetOrigin(newpos, false);

			if (CheckValidity()) { return true; }

			if (position == maxposition && angle != slopeangle) // Try aligning with the plane's slope angle
			{
				angle = slopeangle;
				position = 0;
			}
			else if (position == maxposition && startpos != snappos) // Try snapping to a grid position
			{
				angle = spawnangle;
				startpos = snappos;
				position = 0;
			}
			else
			{
				position++;
			}
		}

		DoDestroy();
		A_StartSound("portal/invalid", CHAN_AUTO);

		Destroy();

		return false;
	}

	bool CheckSpawn()
	{
		Actor spot = FindPortalMapSpot();

		if (spot)
		{
			double zoffset = 0;

			if (spot.pitch)
			{
				if (spot.pitch < 180) { zoffset = 2; }
				else { zoffset = -2; }
			}

			SetOrigin(spot.pos + (0, 0, zoffset), false);
			angle = lineangle = spot.angle;
			linedef = PortalMapSpot(spot).linedef;
			pitch = -spot.pitch;
			roll = spot.roll;

			forcelocation = true;
			if (CheckValidity()) { return true; }
		}

		if (!CheckValidity()) { return Reposition(); }

		return true;
	}

	Actor DoTrace(Actor origin, double angle, double dist, double pitch, Vector3 offset, PortalFindHitPointTracer thistracer)
	{
		if (!origin) { origin = self; }

		offset = RotateVector3(offset, angle, pitch);

		thistracer.skipspecies = origin.species;
		thistracer.skipactor = origin;

		Vector3 tracedir = (cos(angle) * cos(pitch), sin(angle) * cos(pitch), -sin(pitch));
		Vector3 traceloc = origin.pos + offset;

		Actor tracespot = Spawn("Marker", traceloc);

		if (tracespot)
		{
			tracespot.master = self; 

			thistracer.Trace(traceloc, tracespot.CurSector, tracedir, dist, 0);
		}
		else
		{
			thistracer.Trace(traceloc, origin.CurSector, tracedir, dist, 0); // Fall back to the origin sector, just in case...
		}

		return tracespot;
	}

	bool CheckTextureName(TextureID input, String check)
	{
		if (!input) { return false; }

		String texname = TexMan.GetName(input);

		if (texname.IndexOf(".") >= 0) // If it's a long filename
		{
			// Strip the texture name down to only the filename (basically the old-style texture name)
			int start = texname.RightIndexOf("/") + 1;
			texname = texname.Mid(start, texname.RightIndexOf(".") - start);
		}

		if (!(texname.Left(check.length()) ~== check)) { return false; }

		return true;
	}

	override void OnDestroy()
	{
		A_RemoveChildren(TRUE, RMVF_EVERYTHING);
	}

	void CheckOtherActivators()
	{
		if (!noplayers)
		{
			for (int p = 0; p < MAXPLAYERS; p++)
			{
				if (playeringame[p] && Activators.Find(players[p].mo) == Activators.Size()) { Activators.Push(players[p].mo); }
			}
		}

		ThinkerIterator it = ThinkerIterator.Create("Actor", Thinker.STAT_USER);
		Actor mo;

		while (mo = Actor(it.Next(false)))
		{
			if (
				Distance2D(mo) - mo.Default.radius <= 32.0 &&
				Activators.Find(mo) == Activators.Size()
			)
			{
				if (noplayers && !(mo is "HitMarker")) { continue; }

				Activators.Push(mo);
			}

		}
	}

	Actor FindPortalMapspot()
	{
		ThinkerIterator it = ThinkerIterator.Create("PortalMapSpot", Thinker.STAT_USER + 2);
		Actor mo;

		while (mo = Actor(it.Next(true)))
		{
			if (Distance3D(mo) <= 32.0) { return mo; }
		}

		return null;
	}

	void DoDestroy()
	{
		pair = self;

		Actor sparks = Spawn("SparkSpawner", shotpos == (0, 0, 0) ? SpawnPoint : shotpos);
		if (sparks)
		{
			sparks.angle = angle;
			sparks.pitch = pitch;
		}
	}

	double PitchTo(Actor mo, Actor source = null, double zoffset = 0.0)
	{
		if (source == null) { source = self; }

		double distxy = max(source.Distance2D(mo), 1);
		double distz = source.pos.z + zoffset - mo.pos.z;

		return atan(distz / max(distxy, 0.0000001));
	}

	int GetLineAngle()
	{
		if (!linedef) { return int(lineangle); }

		double lineangle;

		if (!linedef.delta.x) { lineangle = 0; }
		else if (!linedef.delta.y) { lineangle = 90; }
		else { lineangle = (atan(linedef.delta.y / linedef.delta.x) + 270) % 360; }

		if (abs(deltaangle(lineangle, angle)) > 90) { lineangle += 180; }

		return int(lineangle);
	}
}

class StaticPortalSpot : PortalSpot
{
	Default
	{
		//$Category Portal/Objects
		//$Title Static Portal Spot (Orange)
	}

	override void PostBeginPlay()
	{
		forcelocation = true;

		Super.PostBeginPlay();

		if (!tid) { ChangeTID(9999); } // Assume that if a static portal has a TID, it was for a reason, and don't reset it for automatic removal.

		frame = 1;
	}

	void PortalSetup(PortalSpot portal, int frame, bool destroyold = true)
	{
		portal.frame = frame;

		portal.camtex = "PORTAL0" .. (frame ? "A" : "B");

		SpriteID spr = GetSpriteIndex("POR0");
		if (spr) { portal.sprite = spr; }

		if (portal.pair) { PortalSpot(portal.pair).pair = portal; }
	}
}

class StaticPortalSpotBlue : StaticPortalSpot // Assumes an orange static portal is already present...
{
	Default
	{
		//$Title Static Portal Spot (Blue)
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		frame = 0;

		ThinkerIterator it = ThinkerIterator.Create("StaticPortalSpot", Thinker.STAT_USER + 1);
		PortalSpot mo;

		if (mo = PortalSpot(it.Next(true)))
		{
			pair = mo;

			PortalSetup(mo, 1, false);
			PortalSetup(self, 0, false);
		}
	}
}

class PortalRing : Actor
{
	Actor light;
	color pri, alt;

	Property PrimaryColor:pri;
	Property SecondaryColor:alt;

	Default
	{
		+NOGRAVITY
		+NOINTERACTION
		+BRIGHT
		RenderStyle "Stencil";
		Alpha 0.8;
		Scale 0.0;
		PortalRing.PrimaryColor "00 7B FF";
		PortalRing.SecondaryColor "FF 84 00";
	}

	States
	{
		Spawn:
			TNT1 A 2;
			PORT # -1;
			Stop;
	}

	override void Tick()
	{
		Super.Tick();

		if (master)
		{
			// If in multiplayer, use the player's color and its compliment as the portal colors
			if (master.master && multiplayer)
			{
				let owner = master.master.player;

				if (owner)
				{
					pri = owner.getColor();
					alt = color("FF FF FF") - pri;
				}
			}
			else
			{
				pri = Default.pri;
				alt = Default.alt;
			}

			SetOrigin(master.pos, false);
		}

		if (frame == 1) { SetShade(alt); }
		else { SetShade(pri); }

		if (scale.x < 1.0) { scale.x = min(scale.x + 0.15, 1.0); }
		if (scale.y < 1.0) { scale.y = min(scale.y + 0.15, 1.0); }

		if (!light)
		{
			light = Spawn("AlphaLight", pos);

			if (light)
			{
				light.master = master;
				AlphaLight(light).maxradius = 20.0;
				AlphaLight(light).clr = fillcolor;
				light.alpha = scale.y;
			}
		}
		else
		{
			AlphaLight(light).clr = fillcolor;
			light.alpha = scale.y;

			if (!PortalSpot(master).bInvisible)
			{
				DynamicLight(light).bAttenuate = true;
				AlphaLight(light).maxradius = 40.0;
			}
			else
			{
				DynamicLight(light).bAttenuate = false;
				AlphaLight(light).maxradius = 20.0;
			}
			
		}
	}
}

class Marker : Actor
{
	Default
	{
		Radius 1;
		Height 1;
		+NOINTERACTION
		+INVISIBLE // Make visible for debug of portal bounds checks
	}

	States
	{
		Spawn:
			AMRK A 15;
			Stop;
	}
}

class PortalTargetSpot : Actor
{
	Default
	{
		//$Category Portal/Objects
		//$Title Portal Target Spot (Launcher Target)
		+DONTSPLASH
		+NOBLOCKMAP
		+NOGRAVITY
		+NOTONAUTOMAP
		+FLATSPRITE
		Height 1;
		Radius 1;
		RenderStyle "None";
	}
	
	States
	{
		Spawn:
			AMRK A -1;
			Stop;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER + 2);

		Super.BeginPlay();
	}
}

class PortalMapSpot : Actor // Default mapspot has height, so can't be used to place floor/ceiling portals.  These also act as aim assist targets for fired portals.
{
	Line linedef;

	Default
	{
		//$Category Portal/Objects
		//$Title Portal Spot (Aim Assist)
		+DONTSPLASH
		+NOBLOCKMAP
		+NOGRAVITY
		+NOTONAUTOMAP
		+WALLSPRITE
		Height 1;
		Radius 1;
		RenderStyle "None";
	}

	States
	{
		Spawn:
			AMRK A -1;
			Stop;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER + 2);

		Super.BeginPlay();
	}

	override void PostBeginPlay()
	{
		linedef = Utilities.GetCurrentLine(self);

		if (linedef)
		{
			double lineangle;

			if (!linedef.delta.x) { lineangle = 0; }
			else if (!linedef.delta.y) { lineangle = 90; }
			else { lineangle = (atan(linedef.delta.y / linedef.delta.x) + 270) % 360; }

			if (abs(deltaangle(lineangle, angle)) > 90) { lineangle += 180; }

			angle = lineangle;
		}

		Super.PostBeginPlay();
	}
}

class PortalCamera : Actor
{
	Default
	{
		+NOBLOCKMAP 
  		+NOGRAVITY
  		+DONTSPLASH
  		CameraHeight 0;
		RenderStyle "None";
	}

	States
	{
		Spawn:
			AMRK A -1;
			Stop;
	}
}