Class PortalFindHitPointTracer : LineTracer
{
	Name skipspecies;
	Actor skipactor;
	bool nogrates;

	override ETraceStatus TraceCallback()
	{
		if (Results.HitType == TRACE_HitActor)
		{
			if (
				Results.HitActor &&
				Results.HitActor != skipactor && // Skip the player
				(!Results.HitActor.master || Results.HitActor.master != skipactor) && // And any children
				(!Results.HitActor.species || Results.HitActor.species != skipspecies) && // And any of the skipped species
				(Results.HitActor.bSolid || Results.HitActor.bShootable) // And only return shootable actors
			)
			{
				if (Results.HitActor is "BlockBase" && Results.HitActor.Master) { Results.HitActor = Results.HitActor.Master; }
//				if (!Results.HitActor.bPushable) { return TRACE_STOP; }

//				return TRACE_Continue; // Fall through, but remember the actor that you hit
			}

			return TRACE_Skip;
		}
		else if (Results.HitType == TRACE_HitFloor || Results.HitType == TRACE_HitCeiling)
		{
			return TRACE_Stop;
		}
		else if (Results.HitType == TRACE_HitWall)
		{
			if (Results.HitLine.flags & (Line.ML_BLOCKING | Line.ML_BLOCKEVERYTHING)) { return TRACE_Stop; }
			if (Results.HitTexture)
			{
				if (!Results.HitLine.alpha) { return TRACE_Skip; }

				String tex = Texman.GetName(Results.HitTexture);

				if (tex ~== "WATERLIN" || tex ~== "KILLGRIL")
				{
					return TRACE_Skip;
				}
				else if (tex.Left(5) ~== "GRATE" || tex ~== "CHAINLNK")
				{
					if (nogrates) { return TRACE_Stop; }
					return TRACE_Skip;
				}
				else if (tex ~== "EMANGRIL")
				{
					Side HitSide = Results.HitLine.sidedef[Results.Side];

					if (HitSide.flags & Side.WALLF_WRAP_MIDTEX || Results.HitLine.flags & Line.ML_WRAP_MIDTEX) { return TRACE_Stop; } // If it's floor-to-ceiling, skip checks

// Well, this is annoying...  Why are all of the Side struct functions play context only?
//					double yoffset = HitSide.GetTextureYOffset(1);
// Offset here is hard-coded at zero....  Better hope Emancipation grilles are only at floor or ceiling level and positioned via lower unpegging being on/off...
					double yoffset = 0.0;
					Vector2 size = TexMan.GetScaledSize(Results.HitTexture);

					double hitz = Results.HitPos.z;
					double floorz = Results.HitSector.floorplane.ZAtPoint(Results.HitPos.xy);
					double ceilingz = Results.HitSector.ceilingplane.ZAtPoint(Results.HitPos.xy);

					if (Results.HitLine.flags & Line.ML_DONTPEGBOTTOM) // Lower unpegged
					{
						if (hitz < floorz + yoffset - 10 || hitz > floorz + yoffset + size.y + 10)
						{
							return TRACE_Skip;
						}
					}
					else
					{
						if (hitz > ceilingz + yoffset + 10 || hitz < ceilingz + yoffset - size.y - 10)
						{
							return TRACE_Skip;
						}
					}
				}
				else if (
					Results.Tier == TIER_Middle && 
					Results.HitLine.flags & Line.ML_TWOSIDED && 
					!(Results.HitLine.flags & Line.ML_3DMIDTEX) && 
					!(
						Results.HitLine.flags & Line.ML_BLOCKING ||
						Results.HitLine.flags & Line.ML_BLOCKEVERYTHING	
					)
				) { return TRACE_Skip; }

				return TRACE_Stop;
			}
			return TRACE_Skip;
		}

		return TRACE_Stop;
	}
}

Class LaserFindHitPointTracer : LineTracer
{
	Name skipspecies;
	Actor skipactor;

	override ETraceStatus TraceCallback()
	{
		if (Results.HitType == TRACE_HitActor)
		{
			if (
				Results.HitActor &&
				Results.HitActor != skipactor && // Skip the origin
				(!Results.HitActor.master || Results.HitActor.master != skipactor) && // And any children
				(!Results.HitActor.species || Results.HitActor.species != skipspecies) && // And any of the skipped species
				(Results.HitActor.bSolid || Results.HitActor.bShootable) // And only return shootable actors
			) { return TRACE_Stop; }

			Results.HitActor = null; // Don't remember if you passed through an actor

			return TRACE_Skip;
		}
		else if (Results.HitTexture)
		{
			String tex = Texman.GetName(Results.HitTexture);

			if (tex.Left(5) ~== "GLASS" || tex.Left(5) ~== "GRATE" || tex ~== "EMANGRIL" || tex ~== "WATERLIN" || tex ~== "KILLGRIL" || tex ~== "CHAINLNK")
			{
				return TRACE_Skip;
			}
		}
		else if (Results.HitType == TRACE_HitFloor || Results.HitType == TRACE_HitCeiling)
		{
			return TRACE_Stop;
		}
		else if (Results.HitType == TRACE_HitWall)
		{
			if (Results.HitLine.flags & (Line.ML_BLOCKING | Line.ML_BLOCKEVERYTHING && Results.HitLine.alpha == 1.0)) { return TRACE_Stop; }
			if (Results.HitTexture)
			{
				if (Results.Tier != TIER_Middle || Results.HitLine.flags & Line.ML_3DMIDTEX) // Midtex check still isn't perfect...
				{
					return TRACE_Stop;
				}
				return TRACE_Skip;
			}
			return TRACE_Skip;
		}

		return TRACE_Stop;
	}
}

Class BridgeFindHitPointTracer : LineTracer
{
	override ETraceStatus TraceCallback()
	{
		if (Results.HitType == TRACE_HitActor)
		{
			return TRACE_Skip;
		}
		else if (Results.HitTexture)
		{
			String tex = Texman.GetName(Results.HitTexture);

			if (tex.Left(5) ~== "GLASS" || tex.Left(5) ~== "GRATE" || tex ~== "EMANGRIL" || tex ~== "WATERLIN" || tex ~== "KILLGRIL" || tex ~== "CHAINLNK")
			{
				return TRACE_Skip;
			}
		}
		else if (Results.HitType == TRACE_HitFloor || Results.HitType == TRACE_HitCeiling)
		{
			return TRACE_Stop;
		}
		else if (Results.HitType == TRACE_HitWall)
		{
			if (Results.HitLine.flags & (Line.ML_BLOCKING | Line.ML_BLOCKEVERYTHING && Results.HitLine.alpha == 1.0)) { return TRACE_Stop; }
			if (Results.HitTexture)
			{
				if (Results.Tier != TIER_Middle || Results.HitLine.flags & Line.ML_3DMIDTEX) // Midtex check still isn't perfect...
				{
					return TRACE_Stop;
				}
				return TRACE_Skip;
			}
			return TRACE_Skip;
		}

		return TRACE_Stop;
	}
}

Class CarryPointTracer : LineTracer
{
	Actor skipactor;

	override ETraceStatus TraceCallback()
	{
		if (Results.HitTexture)
		{
			String tex = Texman.GetName(Results.HitTexture);

			if (tex.Left(5) ~== "GLASS" || tex.Left(5) ~== "GRATE" || tex ~== "KILLGRIL" || tex ~== "CHAINLNK")
			{
				return TRACE_Stop;
			}
		}

		if (Results.HitType == TRACE_HitActor)
		{
			if (skipactor && (Results.HitActor == skipactor || Results.HitActor == skipactor.master || Results.HitActor.master && Results.HitActor.master == skipactor)) { return TRACE_Skip; }
			if (Results.HitActor.bSolid && !Results.HitActor.bNoInteraction) { return TRACE_Stop; }
			return TRACE_Skip;
		}
		else if (Results.HitType == TRACE_HitFloor || Results.HitType == TRACE_HitCeiling)
		{
			return TRACE_Stop;
		}
		else if (Results.HitType == TRACE_HitWall)
		{
			if (Results.HitLine.flags & (Line.ML_BLOCKING | Line.ML_BLOCKEVERYTHING) && Results.HitLine.alpha == 1.0) { return TRACE_Stop; }
			if (Results.HitTexture)
			{
				if (Results.Tier != TIER_Middle || Results.HitLine.flags & Line.ML_3DMIDTEX) // Midtex check still isn't perfect...
				{
					return TRACE_Stop;
				}
				return TRACE_Skip;
			}
			return TRACE_Skip;
		}

		return TRACE_Stop;
	}
}

Class UsePointTracer : LineTracer
{
	Name skipspecies;
	Actor skipactor;

	override ETraceStatus TraceCallback()
	{
		if (Results.HitType == TRACE_HitActor)
		{
			if (
				Results.HitActor &&
				Results.HitActor != skipactor && // Skip the player
				(!Results.HitActor.master || Results.HitActor.master != skipactor) && // And any children
				(!Results.HitActor.species || Results.HitActor.species != skipspecies) && // And any of the skipped species
				(Results.HitActor.bSolid || Results.HitActor.bShootable) // And only return shootable actors
			)
			{
				if (Results.HitActor is "BlockBase" && Results.HitActor.Master) { Results.HitActor = Results.HitActor.Master; }
				return TRACE_STOP;
			}

			return TRACE_Skip;
		}
		else if (Results.HitType == TRACE_HitFloor || Results.HitType == TRACE_HitCeiling)
		{
			return TRACE_Stop;
		}
		else if (Results.HitType == TRACE_HitWall)
		{
			if (Results.HitLine.flags & (Line.ML_BLOCKING | Line.ML_BLOCKEVERYTHING)) { return TRACE_Stop; }
			if (Results.HitTexture)
			{
				if (Texman.GetName(Results.HitTexture) ~== "WATERLIN" || Texman.GetName(Results.HitTexture) ~== "KILLGRIL")
				{
					return TRACE_Skip;
				}
				else if (Texman.GetName(Results.HitTexture) ~== "GRATE" || Texman.GetName(Results.HitTexture) ~== "CHAINLNK")
				{
					return TRACE_Skip;
				}
				else if (Texman.GetName(Results.HitTexture) ~== "EMANGRIL" && !(Results.HitLine.flags & Line.ML_WRAP_MIDTEX)) // If it's floor-to-ceiling, skip checks
				{
					if (!Results.HitLine.alpha) { return TRACE_Skip; }

					Side HitSide = Results.HitLine.sidedef[Results.Side];

					if (HitSide.flags & Side.WALLF_WRAP_MIDTEX || Results.HitLine.flags & Line.ML_WRAP_MIDTEX) { return TRACE_Stop; } // If it's floor-to-ceiling, skip checks

// Well, this is annoying...  Why are all of the Side struct functions play context only?
//					double yoffset = HitSide.GetTextureYOffset(1);
// Offset here is hard-coded at zero....  Better hope Emancipation grilles are only at floor or ceiling level and positioned via lower unpegging being on/off...
					double yoffset = 0.0;
					Vector2 size = TexMan.GetScaledSize(Results.HitTexture);

					double hitz = Results.HitPos.z;
					double floorz = Results.HitSector.floorplane.ZAtPoint(Results.HitPos.xy);
					double ceilingz = Results.HitSector.ceilingplane.ZAtPoint(Results.HitPos.xy);

					if (Results.HitLine.flags & Line.ML_DONTPEGBOTTOM) // Lower unpegged
					{
						if (hitz < floorz + yoffset - 10 || hitz > floorz + yoffset + size.y + 10)
						{
							return TRACE_Skip;
						}
					}
					else
					{
						if (hitz > ceilingz + yoffset + 10 || hitz < ceilingz + yoffset - size.y - 10)
						{
							return TRACE_Skip;
						}
					}
				}
				return TRACE_Stop;
			}
			return TRACE_Skip;
		}

		return TRACE_Stop;
	}
}