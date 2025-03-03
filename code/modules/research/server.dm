/obj/machinery/r_n_d/server
	name = "R&D Server"
	icon = 'icons/obj/machines/research.dmi'
	icon_state = "server"
	light_color = "#a97faa"
	var/datum/research/files
	var/health = 100
	var/list/id_with_upload = list()		//List of R&D consoles with upload to server access.
	var/list/id_with_download = list()	//List of R&D consoles with download from server access.
	var/id_with_upload_string = ""		//String versions for easy editing in map editor.
	var/id_with_download_string = ""
	var/server_id = 0
	var/heat_gen = 100
	var/heating_power = 40000
	var/delay = 10
	req_access = list(access_rd) //Only the R&D can change server settings.

/obj/machinery/r_n_d/server/atom_init()
	. = ..()
	rnd_server_list += src
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/rdserver(null)
	component_parts += new /obj/item/weapon/stock_parts/scanning_module(null)
	component_parts += new /obj/item/stack/cable_coil/red(null, 1)
	component_parts += new /obj/item/stack/cable_coil/red(null, 1)
	RefreshParts()

/obj/machinery/r_n_d/server/Destroy()
	griefProtection()
	rnd_server_list -= src
	return ..()

/obj/machinery/r_n_d/server/RefreshParts()
	var/tot_rating = 0
	for(var/obj/item/weapon/stock_parts/SP in src)
		tot_rating += SP.rating
	heat_gen /= max(1, tot_rating)

/obj/machinery/r_n_d/server/atom_init()
	. = ..()
	if(!files)
		files = new /datum/research(src)
	var/list/temp_list
	if(!id_with_upload.len)
		temp_list = list()
		temp_list = splittext(id_with_upload_string, ";")
		for(var/N in temp_list)
			id_with_upload += text2num(N)
	if(!id_with_download.len)
		temp_list = list()
		temp_list = splittext(id_with_download_string, ";")
		for(var/N in temp_list)
			id_with_download += text2num(N)

/obj/machinery/r_n_d/server/process()
	var/datum/gas_mixture/environment = loc.return_air()
	switch(environment.temperature)
		if(0 to T0C)
			health = min(100, health + 1)
		if(T0C to (T20C + 20))
			health = between(0, health, 100)
		if((T20C + 20) to (T0C + 70))
			health = max(0, health - 1)
	if(health <= 0)
		griefProtection() //I dont like putting this in process() but it's the best I can do without re-writing a chunk of rd servers.
		files.forget_random_technology()
	if(delay)
		delay--
	else
		produce_heat(heat_gen)
		delay = initial(delay)


/obj/machinery/r_n_d/server/emp_act(severity)
	griefProtection()
	..()


/obj/machinery/r_n_d/server/ex_act(severity)
	griefProtection()
	..()


/obj/machinery/r_n_d/server/blob_act()
	griefProtection()
	..()



//Backup files to centcomm to help admins recover data after greifer attacks
/obj/machinery/r_n_d/server/proc/griefProtection()
	for(var/obj/machinery/r_n_d/server/centcom/C in rnd_server_list)
		C.files.download_from(files)

/obj/machinery/r_n_d/server/proc/produce_heat(heat_amt)
	if(!(stat & (NOPOWER|BROKEN))) //Blatently stolen from space heater.
		var/turf/simulated/L = loc
		if(istype(L))
			var/datum/gas_mixture/env = L.return_air()

			var/transfer_moles = 0.25 * env.total_moles

			var/datum/gas_mixture/removed = env.remove(transfer_moles)

			if(removed)
				var/heat_produced = idle_power_usage	//obviously can't produce more heat than the machine draws from it's power source

				removed.add_thermal_energy(heat_produced)

			env.merge(removed)

/obj/machinery/r_n_d/server/attackby(obj/item/I, mob/user)
	if (disabled)
		return
	if (shocked)
		shock(user,50)
	if (default_deconstruction_screwdriver(user, "server_o", "server", I))
		return
	if(exchange_parts(user, I))
		return
	if (panel_open)
		if(iscrowbar(I))
			griefProtection()
			default_deconstruction_crowbar(I)
			return 1
		else if (is_wire_tool(I) && wires.interact(user))
			return 1

/obj/machinery/r_n_d/server/centcom
	name = "Centcom Central R&D Database"
	server_id = -1

/obj/machinery/r_n_d/server/centcom/atom_init()
	. = ..()
	var/list/no_id_servers = list()
	var/list/server_ids = list()
	for(var/obj/machinery/r_n_d/server/S in rnd_server_list)
		switch(S.server_id)
			if(-1)
				continue
			if(0)
				no_id_servers += S
			else
				server_ids += S.server_id

	for(var/obj/machinery/r_n_d/server/S in no_id_servers)
		var/num = 1
		while(!S.server_id)
			if(num in server_ids)
				num++
			else
				S.server_id = num
				server_ids += num
		no_id_servers -= S

/obj/machinery/r_n_d/server/centcom/process()
	return PROCESS_KILL	//don't need process()


/obj/machinery/computer/rdservercontrol
	name = "R&D Server Controller"
	icon_state = "rdcomp"
	circuit = /obj/item/weapon/circuitboard/rdservercontrol
	var/screen = 0
	var/obj/machinery/r_n_d/server/temp_server
	var/list/servers = list()
	var/list/consoles = list()
	var/badmin = 0
	required_skills = list(/datum/skill/research = SKILL_LEVEL_PRO)

/obj/machinery/computer/rdservercontrol/Topic(href, href_list)
	. = ..()
	if(!.)
		return

	if(!allowed(usr) && !emagged)
		to_chat(usr, "<span class='warning'>You do not have the required access level</span>")
		return FALSE

	if(href_list["main"])
		screen = 0

	else if(href_list["access"] || href_list["data"] || href_list["transfer"])
		temp_server = null
		consoles = list()
		servers = list()
		for(var/obj/machinery/r_n_d/server/S in rnd_server_list)
			if(S.server_id == text2num(href_list["access"]) || S.server_id == text2num(href_list["data"]) || S.server_id == text2num(href_list["transfer"]))
				temp_server = S
				break
		if(href_list["access"])
			screen = 1
			for(var/obj/machinery/computer/rdconsole/C in computer_list)
				if(C.sync)
					consoles += C
		else if(href_list["data"])
			screen = 2
		else if(href_list["transfer"])
			screen = 3
			for(var/obj/machinery/r_n_d/server/S in rnd_server_list)
				if(S == src)
					continue
				servers += S

	else if(href_list["upload_toggle"])
		var/num = text2num(href_list["upload_toggle"])
		if(num in temp_server.id_with_upload)
			temp_server.id_with_upload -= num
		else
			temp_server.id_with_upload += num

	else if(href_list["download_toggle"])
		var/num = text2num(href_list["download_toggle"])
		if(num in temp_server.id_with_download)
			temp_server.id_with_download -= num
		else
			temp_server.id_with_download += num

	else if(href_list["reset_tech"])
		var/choice = tgui_alert(usr, "Are you sure you want to reset this technology to its default data? Data lost cannot be recovered.", "Technology Data Rest", list("Continue", "Cancel"))
		if(choice == "Continue")
			temp_server.files.forget_all(href_list["reset_tech"])

	else if(href_list["reset_techology"])
		var/choice = tgui_alert(usr, "Are you sure you want to delete this techology? Data lost cannot be recovered.", "Techology Deletion", list("Continue", "Cancel"))
		var/techology = temp_server.files.researched_tech[href_list["reset_techology"]]
		if(choice == "Continue" && techology)
			temp_server.files.forget_techology(techology)

	updateUsrDialog()

/obj/machinery/computer/rdservercontrol/ui_interact(mob/user)
	var/dat = ""

	switch(screen)
		if(0) //Main Menu
			dat += "Connected Servers:<BR><BR>"
			for(var/obj/machinery/r_n_d/server/S in rnd_server_list)
				if(istype(S, /obj/machinery/r_n_d/server/centcom) && !badmin)
					continue
				dat += "<table><tr>"
				dat += "<td>[S.name]</td>"
				dat += "<td><A href='?src=\ref[src];access=[S.server_id]'>Access Rights</A></td>"
				dat += "<td><A href='?src=\ref[src];data=[S.server_id]'>Data Management</A></td>"
				if(badmin)
					dat += "<td><A href='?src=\ref[src];transfer=[S.server_id]'>Server-to-Server Transfer</A></td>"
				dat += "</tr></table>"
				dat += "<BR>"

		if(1) //Access rights menu
			dat += "[temp_server.name] Access Rights<BR><BR>"
			dat += "Consoles with Upload Access<BR>"
			for(var/obj/machinery/computer/rdconsole/C in consoles)
				var/turf/console_turf = get_turf(C)
				dat += "* <A href='?src=\ref[src];upload_toggle=[C.id]'>[console_turf.loc]" //FYI, these are all numeric ids, eventually.
				if(C.id in temp_server.id_with_upload)
					dat += "Remove</A><BR>"
				else
					dat += "Add</A><BR>"
			dat += "Consoles with Download Access<BR>"
			for(var/obj/machinery/computer/rdconsole/C in consoles)
				var/turf/console_turf = get_turf(C)
				dat += "* <A href='?src=\ref[src];download_toggle=[C.id]'>[console_turf.loc]"
				if(C.id in temp_server.id_with_download)
					dat += "Remove</A><BR>"
				else
					dat += "Add</A><BR>"
			dat += "<HR><A href='?src=\ref[src];main=1'>Main Menu</A>"

		if(2) //Data Management menu
			dat += "[temp_server.name] Data ManagementP<BR><BR>"
			dat += "Known Tech Trees<BR>"
			for(var/tech_tree in temp_server.files.tech_trees)
				var/datum/tech/T = temp_server.files.tech_trees[tech_tree]
				dat += "* [T.name] "
				dat += "<A href='?src=\ref[src];reset_tech=[T.id]'>(Reset)</A><BR>" //FYI, these are all strings.
			dat += "Known Technologies<BR>"
			for(var/techology_id in temp_server.files.researched_tech)
				var/datum/technology/T = temp_server.files.researched_tech[techology_id]
				dat += "* [T.name] "
				dat += "<A href='?src=\ref[src];reset_techology=[T.id]'>(Delete)</A><BR>"
			dat += "<HR><A href='?src=\ref[src];main=1'>Main Menu</A>"

		if(3) //Server Data Transfer
			dat += "[temp_server.name] Server to Server Transfer<BR><BR>"
			dat += "Send Data to what server?<BR>"
			for(var/obj/machinery/r_n_d/server/S in servers)
				dat += "[S.name] <A href='?src=\ref[src];send_to=[S.server_id]'> (Transfer)</A><BR>"
			dat += "<HR><A href='?src=\ref[src];main=1'>Main Menu</A>"

	var/datum/browser/popup = new(user, "server_control", "R&D Server Control", 575, 400)
	popup.set_content(dat)
	popup.open()


/obj/machinery/computer/rdservercontrol/attackby(obj/item/weapon/D, mob/user)
	..()
	updateUsrDialog()

/obj/machinery/computer/rdservercontrol/emag_act(mob/user)
	if(!emagged)
		playsound(src, 'sound/effects/sparks4.ogg', VOL_EFFECTS_MASTER)
		emagged = 1
		user.SetNextMove(CLICK_CD_INTERACT)
		to_chat(user, "<span class='notice'>You you disable the security protocols</span>")
		return TRUE
	return FALSE

/obj/machinery/r_n_d/server/robotics
	name = "Robotics R&D Server"
	id_with_upload_string = "1;2"
	id_with_download_string = "1;2"
	server_id = 2


/obj/machinery/r_n_d/server/core
	name = "Core R&D Server"
	id_with_upload_string = "1"
	id_with_download_string = "1"
	server_id = 1

/obj/machinery/r_n_d/server/mining
	name = "Mining R&D Server"
	id_with_upload_string = "1;3"
	id_with_download_string = "1;3"
	server_id = 3
