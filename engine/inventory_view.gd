extends RefCounted
var app

func setup(owner_app) -> void:
	app = owner_app

func describe(box: VBoxContainer, item: String, count: int) -> void:
	var spec: Dictionary = app.core.content.items[item]
	box.add_child(app.label("%s × %d" % [app.t(spec.name),count],26))
	var detail: Label = app.label(app.t(spec.get("description","item_no_description")),20)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)

func show_inventory() -> void:
	var box: VBoxContainer = app.modal(app.t("inventory"))
	var count := 0
	for item in app.core.state.inventory:
		var amount := int(app.core.state.inventory[item])
		if amount <= 0: continue
		count += 1
		describe(box,item,amount)
		var targets := 0
		for target in app.core.map_objects():
			if target.kind != "inspect" or not target.has("required_item") or target.required_item.id != item: continue
			if not app.core.target_visible(target) or (app.core.state.objects.get(target.id,false) and not target.get("repeatable",false)): continue
			targets += 1
			var reason: String = "" if app.core.adjacent(target.position) else "too_far"
			if amount < target.required_item.count: reason = "item_required"
			var use: Button = app.button(app.t("use_item")+" ×%d · " % target.required_item.count+app.t(target.get("label",target.id)),func(): app.execute({"op":"interact","target":target.id,"item":item}))
			use.name = "InventoryUse_"+target.id
			use.disabled = reason != ""
			box.add_child(use)
			box.add_child(app.label(app.t(reason) if reason != "" else app.t("item_consumed") if target.required_item.consume else app.t("item_kept"),18))
		if targets == 0: box.add_child(app.label(app.t("item_story_use"),18))
	if count == 0: box.add_child(app.label(app.t("inventory_empty"),22))
	box.add_child(app.button(app.t("back"),app.close_modal))

func show_shop(shop: String) -> void:
	var box: VBoxContainer = app.modal(app.t("counter"))
	box.add_child(app.label(app.t("money")+": "+str(int(app.core.state.money)),24))
	for item in app.core.content.shops[shop]:
		var offer: Dictionary = app.core.shop_offer(shop,item)
		describe(box,item,int(offer.owned))
		box.add_child(app.label(app.t("stock_remaining")+": "+(("無限" if app.language == "zh_TW" else "Unlimited") if offer.unlimited else str(offer.stock)),20))
		var buy: Button = app.button("%s — %d" % [app.t(app.core.content.items[item].name),offer.price],func(): app.execute({"op":"buy","shop":shop,"item":item}))
		buy.name = "ShopBuy_"+item
		buy.disabled = not offer.available
		box.add_child(buy)
		if not offer.available: box.add_child(app.label(app.t(offer.reason),20))
	box.add_child(app.button(app.t("back"),app.close_modal))
