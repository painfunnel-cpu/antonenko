import { createClient } from "@supabase/supabase-js";

export const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string;
export const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string;
export const supabase = createClient(supabaseUrl, supabaseAnonKey, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } });

export type Profile = { id: string; full_name: string | null; phone: string | null; city: string | null; address: string | null; avatar_url: string | null; role: "customer" | "admin" };
export type DbProduct = { id: string; slug: string; name: string; subtitle: string; description: string; price: number; category: string; image_url: string | null; tag: string | null; is_active: boolean; sort_order: number };
export type DbOrder = { id: string; order_number: string; user_id: string; status: "new" | "processing" | "delivering" | "delivered" | "cancelled"; customer_name: string; phone: string; city: string; address: string; comment: string | null; total: number; created_at: string; order_items?: { product_name: string; unit_price: number; quantity: number; line_total: number }[]; profiles?: Profile | null };

export const statusToRu: Record<DbOrder["status"], string> = { new: "Новый", processing: "В работе", delivering: "Доставляется", delivered: "Доставлен", cancelled: "Отменён" };
export const statusToDb: Record<string, DbOrder["status"]> = { "Новый": "new", "В работе": "processing", "Доставляется": "delivering", "Доставлен": "delivered", "Отменён": "cancelled" };

export async function loadProducts() { const { data, error } = await supabase.from("products").select("*").eq("is_active", true).order("sort_order"); return { data: (data || []) as DbProduct[], error }; }
export async function loadProfile(userId: string) { const { data, error } = await supabase.from("profiles").select("*").eq("id", userId).maybeSingle(); return { data: data as Profile | null, error }; }
export async function saveProfile(userId: string, values: Partial<Profile>) { return supabase.from("profiles").update({ ...values, updated_at: new Date().toISOString() }).eq("id", userId).select("*").single(); }
export async function loadMyOrders(userId: string) { const { data, error } = await supabase.from("orders").select("*, order_items(*)").eq("user_id", userId).order("created_at", { ascending: false }); return { data: (data || []) as DbOrder[], error }; }
export async function loadAllOrders() { const { data, error } = await supabase.from("orders").select("*, order_items(*), profiles(*)").order("created_at", { ascending: false }); return { data: (data || []) as DbOrder[], error }; }
export async function updateOrderStatus(id: string, status: string) {
  const byUuid = await supabase.from("orders").update({ status: statusToDb[status] || "new" }).eq("id", id);
  if (!byUuid.error && byUuid.count !== 0) return byUuid;
  return supabase.from("orders").update({ status: statusToDb[status] || "new" }).eq("order_number", id);
}
export async function createOrder(input: { userId: string; customerName: string; phone: string; city: string; address: string; comment?: string; total: number; items: { productId?: string; productName: string; unitPrice: number; quantity: number }[] }) {
  const { data: order, error } = await supabase.from("orders").insert({ user_id: input.userId, customer_name: input.customerName, phone: input.phone, city: input.city, address: input.address, comment: input.comment || null, total: input.total }).select("*").single();
  if (error || !order) return { data: null, error };
  const rows = input.items.map((item) => ({ order_id: order.id, product_id: item.productId || null, product_name: item.productName, unit_price: item.unitPrice, quantity: item.quantity, line_total: item.unitPrice * item.quantity }));
  const itemsResult = await supabase.from("order_items").insert(rows);
  return { data: order as DbOrder, error: itemsResult.error };
}

export async function signUp(email: string, password: string, fullName: string) { return supabase.auth.signUp({ email, password, options: { data: { full_name: fullName } } }); }
export async function signIn(email: string, password: string) { return supabase.auth.signInWithPassword({ email, password }); }
export async function signOut() { return supabase.auth.signOut(); }
