"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function submitOrganizerApplication(formData: FormData) {
  const supabase = await createClient();
  if (!supabase) redirect("/organizer?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?next=/organizer");

  const name = String(formData.get("name") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const contactPhone = String(formData.get("contact_phone") ?? "").trim();
  if (name.length < 2 || name.length > 160 || contactPhone.length < 7 || contactPhone.length > 40) {
    redirect("/organizer?error=invalid");
  }

  const { error } = await supabase.from("organizers").insert({
    user_id: user.id,
    name,
    description: description || null,
    contact_phone: contactPhone,
    status: "pending",
  });
  if (error) redirect("/organizer?error=save");
  revalidatePath("/organizer");
  redirect("/organizer?submitted=1");
}


export async function createTicketOrder(formData: FormData) {
  const supabase = await createClient();
  if (!supabase) redirect("/?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const eventId = String(formData.get("event_id") ?? "");
  const ticketTypeId = String(formData.get("ticket_type_id") ?? "");
  const idempotencyKey = String(formData.get("idempotency_key") ?? "");
  const quantity = Number(formData.get("quantity") ?? 1);
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidPattern.test(eventId) || !uuidPattern.test(ticketTypeId) || idempotencyKey.length < 8 || idempotencyKey.length > 128 || !Number.isInteger(quantity) || quantity < 1 || quantity > 10) {
    redirect("/?error=invalid_order");
  }

  const { data, error } = await supabase.rpc("create_ticket_order", {
    p_ticket_type_id: ticketTypeId,
    p_quantity: quantity,
    p_idempotency_key: idempotencyKey,
  });
  if (error || !data) redirect(`/events/${eventId}?error=order_failed`);
  redirect(`/orders/${data}`);
}

export async function submitPaymentReference(formData: FormData) {
  const supabase = await createClient();
  if (!supabase) redirect("/?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const orderId = String(formData.get("order_id") ?? "");
  const provider = String(formData.get("provider") ?? "").trim();
  const reference = String(formData.get("provider_reference") ?? "").trim();
  const amount = Number(formData.get("amount_ugx") ?? NaN);
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidPattern.test(orderId) || provider.length < 2 || provider.length > 80 || reference.length < 4 || reference.length > 160 || !Number.isSafeInteger(amount) || amount < 0) {
    redirect(`/orders/${orderId}?error=invalid_reference`);
  }

  const { error } = await supabase.rpc("submit_payment_reference", {
    p_order_id: orderId,
    p_provider: provider,
    p_provider_reference: reference,
    p_amount_ugx: amount,
  });
  if (error) redirect(`/orders/${orderId}?error=reference_failed`);
  revalidatePath(`/orders/${orderId}`);
  redirect(`/orders/${orderId}?reference_submitted=1`);
}

export async function cancelTicketOrder(formData: FormData) {
  const supabase = await createClient();
  if (!supabase) redirect("/?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const orderId = String(formData.get("order_id") ?? "");
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidPattern.test(orderId)) redirect("/?error=invalid_order");
  const { error } = await supabase.rpc("cancel_ticket_order", { p_order_id: orderId });
  if (error) redirect(`/orders/${orderId}?error=cancel_failed`);
  revalidatePath(`/orders/${orderId}`);
  redirect(`/orders/${orderId}?cancelled=1`);
}


export async function submitEventWithTicket(formData: FormData) {
  const supabase = await createClient();
  if (!supabase) redirect("/?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?next=/organizer/events/new");

  const title = String(formData.get("title") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const categoryId = String(formData.get("category_id") ?? "");
  const venueIdRaw = String(formData.get("venue_id") ?? "");
  const paymentMethodIdRaw = String(formData.get("payment_method_id") ?? "");
  const startsAtRaw = String(formData.get("starts_at") ?? "");
  const endsAtRaw = String(formData.get("ends_at") ?? "");
  const ticketName = String(formData.get("ticket_name") ?? "General admission").trim();
  const price = Number(formData.get("price_ugx") ?? NaN);
  const quantity = Number(formData.get("quantity") ?? NaN);
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const startsAt = new Date(startsAtRaw + ":00+03:00");
  const endsAt = new Date(endsAtRaw + ":00+03:00");

  if (title.length < 3 || title.length > 180 || !uuidPattern.test(categoryId) ||
      (venueIdRaw && !uuidPattern.test(venueIdRaw)) ||
      (paymentMethodIdRaw && !uuidPattern.test(paymentMethodIdRaw)) ||
      !Number.isFinite(startsAt.getTime()) || !Number.isFinite(endsAt.getTime()) ||
      startsAt.getTime() <= Date.now() || endsAt.getTime() <= startsAt.getTime() ||
      ticketName.length < 1 || ticketName.length > 100 ||
      !Number.isSafeInteger(price) || price < 0 ||
      !Number.isSafeInteger(quantity) || quantity < 1 || quantity > 100000) {
    redirect("/organizer/events/new?error=invalid");
  }

  const { data: eventId, error } = await supabase.rpc("submit_event_with_ticket", {
    p_category_id: categoryId,
    p_title: title,
    p_description: description || null,
    p_venue_id: venueIdRaw || null,
    p_payment_method_id: paymentMethodIdRaw || null,
    p_starts_at: startsAt.toISOString(),
    p_ends_at: endsAt.toISOString(),
    p_ticket_name: ticketName,
    p_price_ugx: price,
    p_quantity: quantity,
  });
  if (error || !eventId) redirect("/organizer/events/new?error=submit_failed");
  revalidatePath("/");
  redirect(`/organizer?event_submitted=${eventId}`);
}


export async function addOrganizerPaymentMethod(formData: FormData) {
  const supabase = await createClient();
  if (!supabase) redirect("/?error=setup");
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?next=/organizer/payment-methods/new");
  const method = String(formData.get("method") ?? "");
  const provider = String(formData.get("provider") ?? "").trim();
  const accountIdentifier = String(formData.get("account_identifier") ?? "").trim();
  const accountName = String(formData.get("account_name") ?? "").trim();
  const allowed = ["airtel_money", "mtn_momo", "bank_transfer", "card", "other"];
  if (!allowed.includes(method) || provider.length < 2 || provider.length > 80 ||
      accountIdentifier.length < 3 || accountIdentifier.length > 160 ||
      accountName.length < 2 || accountName.length > 160) {
    redirect("/organizer/payment-methods/new?error=invalid");
  }

  const { data: organizer } = await supabase.from("organizers").select("id").eq("user_id", user.id).maybeSingle();
  if (!organizer) redirect("/organizer?error=application_required");
  const { error } = await supabase.from("organizer_payment_methods").insert({
    organizer_id: organizer.id,
    method,
    provider,
    account_identifier: accountIdentifier,
    account_name: accountName,
    verification_status: "pending",
    active: false,
  });
  if (error) redirect("/organizer/payment-methods/new?error=save");
  revalidatePath("/organizer");
  redirect("/organizer?payment_method_submitted=1");
}
