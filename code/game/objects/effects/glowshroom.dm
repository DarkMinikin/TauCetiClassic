//separate dm since hydro is getting bloated already

/obj/effect/glowshroom
	name = "glowshroom"
	anchored = TRUE
	opacity = 0
	density = FALSE
	icon = 'icons/obj/lighting.dmi'
	icon_state = "glowshroomf"
	layer = 2.1
	light_power = 0.7
	light_color = "#80b82e"
	var/endurance = 30
	var/potency = 30
	var/delay = 1200
	var/floor = 0
	var/yield = 3
	var/spreadChance = 40
	var/spreadIntoAdjacentChance = 60
	var/evolveChance = 2
	var/lastTick = 0
	var/spreaded = 1

/obj/effect/glowshroom/single
	spreadChance = 0

/obj/effect/glowshroom/atom_init()

	. = ..()

	set_dir(CalcDir())

	if(!floor)
		switch(dir) //offset to make it be on the wall rather than on the floor
			if(NORTH)
				pixel_y = 32
			if(SOUTH)
				pixel_y = -32
			if(EAST)
				pixel_x = 32
			if(WEST)
				pixel_x = -32
		icon_state = "glowshroom[rand(1,3)]"
	else //if on the floor, glowshroom on-floor sprite
		icon_state = "glowshroomf"

	START_PROCESSING(SSobj, src)

	set_light(round(potency/10), light_power, light_color)
	lastTick = world.timeofday

/obj/effect/glowshroom/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/effect/glowshroom/process()
	if(!spreaded)
		return
	STOP_PROCESSING(SSobj, src)
	if(((world.timeofday - lastTick) > delay) || ((world.timeofday - lastTick) < 0))
		lastTick = world.timeofday
		spreaded = 0

		for(var/i=1,i<=yield,i++)
			if(prob(spreadChance))
				var/list/possibleLocs = list()
				var/spreadsIntoAdjacent = 0

				if(prob(spreadIntoAdjacentChance))
					spreadsIntoAdjacent = 1

				for(var/turf/simulated/floor/plating/airless/asteroid/earth in view(3,src))
					if(spreadsIntoAdjacent || !locate(/obj/effect/glowshroom) in view(1,earth))
						possibleLocs += earth

				if(!possibleLocs.len)
					break

				var/turf/newLoc = pick(possibleLocs)

				var/shroomCount = 0 //hacky
				var/placeCount = 1
				for(var/obj/effect/glowshroom/shroom in newLoc)
					shroomCount++
				for(var/wallDir in cardinal)
					var/turf/isWall = get_step(newLoc,wallDir)
					if(isWall.density)
						placeCount++
				if(shroomCount >= placeCount)
					continue

				var/obj/effect/glowshroom/child = new /obj/effect/glowshroom(newLoc)
				child.potency = potency
				child.yield = yield
				child.delay = delay
				child.endurance = endurance

				spreaded++

		if(prob(evolveChance)) //very low chance to evolve on its own
			potency += rand(4,6)

/obj/effect/glowshroom/proc/CalcDir(turf/location = loc)
	//set background = 1
	var/direction = 16

	for(var/wallDir in cardinal)
		var/turf/newTurf = get_step(location,wallDir)
		if(newTurf.density)
			direction |= wallDir

	for(var/obj/effect/glowshroom/shroom in location)
		if(shroom == src)
			continue
		if(shroom.floor) //special
			direction &= ~16
		else
			direction &= ~shroom.dir

	var/list/dirList = list()

	for(var/i=1,i<=16,i <<= 1)
		if(direction & i)
			dirList += i

	if(dirList.len)
		var/newDir = pick(dirList)
		if(newDir == 16)
			floor = 1
			newDir = 1
		return newDir

	floor = 1
	return 1

/obj/effect/glowshroom/attackby(obj/item/weapon/W, mob/user)
	..()

	endurance -= W.force

	CheckEndurance()

/obj/effect/glowshroom/ex_act(severity)
	switch(severity)
		if(EXPLODE_HEAVY)
			if(prob(50))
				return
		if(EXPLODE_LIGHT)
			if(prob(95))
				return
	qdel(src)

/obj/effect/glowshroom/fire_act(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	if(exposed_temperature > 300)
		endurance -= 5
		CheckEndurance()

/obj/effect/glowshroom/proc/CheckEndurance()
	if(endurance <= 0)
		qdel(src)
