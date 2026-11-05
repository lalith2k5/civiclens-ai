"use client";
import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken } from "@/lib/api";

export default function Admin() {
  const [activeTab, setActiveTab] = useState("wards");
  const queryClient = useQueryClient();

  // Queries
  const { data: wards } = useQuery({ queryKey: ["wards"], queryFn: () => fetch(`${API_URL}/admin/wards`).then(r => r.json()) });
  const { data: depts } = useQuery({ queryKey: ["depts"], queryFn: () => fetch(`${API_URL}/admin/departments`).then(r => r.json()) });
  const { data: users } = useQuery({ queryKey: ["users"], queryFn: () => fetch(`${API_URL}/admin/users`).then(r => r.json()) });
  const { data: slas } = useQuery({ queryKey: ["slas"], queryFn: () => fetch(`${API_URL}/admin/sla`).then(r => r.json()) });
  const { data: categories } = useQuery({ queryKey: ["categories"], queryFn: () => fetch(`${API_URL}/admin/categories`).then(r => r.json()) });
  const { data: workflow } = useQuery({ queryKey: ["workflow"], queryFn: () => fetch(`${API_URL}/admin/workflow`).then(r => r.json()) });
  const { data: workspace } = useQuery({ queryKey: ["workspace"], queryFn: () => fetch(`${API_URL}/admin/workspace`).then(r => r.json()) });

  const updateSla = useMutation({
    mutationFn: ({ priority, hours }: { priority: string, hours: number }) => fetch(`${API_URL}/admin/sla`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ priority, hours }) }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["slas"] })
  });

  // Mutations
  const addWard = useMutation({
    mutationFn: (name: string) => fetch(`${API_URL}/admin/wards`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name, code: "NEW" }) }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["wards"] })
  });

  const addDept = useMutation({
    mutationFn: (name: string) => fetch(`${API_URL}/admin/departments`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["depts"] })
  });

  const updateRole = useMutation({
    mutationFn: ({ id, role }: { id: number, role: string }) => fetch(`${API_URL}/admin/users/${id}/role`, { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ role }) }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["users"] })
  });

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-slate-900">Admin Configuration</h2>
      
      <div className="flex gap-2 border-b">
        {["wards", "departments", "users", "categories", "workflow", "workspace", "sla"].map(tab => (
          <button key={tab} onClick={() => setActiveTab(tab)} className={`px-4 py-2 font-medium capitalize border-b-2 ${activeTab === tab ? 'border-primary text-primary' : 'border-transparent text-slate-500'}`}>{tab}</button>
        ))}
      </div>

      {activeTab === "wards" && (
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <div className="flex gap-2 mb-4">
            <input id="wardName" className="border p-2 rounded w-full" placeholder="New Ward Name" />
            <Button onClick={() => { const el = document.getElementById('wardName') as HTMLInputElement; if(el.value) { addWard.mutate(el.value); el.value = ''; } }}>Add</Button>
          </div>
          <input type="file" accept=".geojson,.json" className="mb-4" onChange={async (e) => { const file = e.target.files?.[0]; if (file) { const text = await file.text(); const json = JSON.parse(text); await fetch(`${API_URL}/admin/wards/import`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(json) }); window.location.reload(); } }} />
          <ul className="space-y-2">
            {wards?.map((w: any) => <li key={w.id} className="p-3 bg-slate-50 rounded border flex justify-between">{w.name} <Badge>{w.code}</Badge></li>)}
          </ul>
        </div>
      )}

      {activeTab === "departments" && (
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <div className="flex gap-2 mb-4">
            <input id="deptName" className="border p-2 rounded w-full" placeholder="New Department Name" />
            <Button onClick={() => { const el = document.getElementById('deptName') as HTMLInputElement; if(el.value) { addDept.mutate(el.value); el.value = ''; } }}>Add</Button>
          </div>
          <ul className="space-y-2">
            {depts?.map((d: any) => <li key={d.id} className="p-3 bg-slate-50 rounded border">{d.name}</li>)}
          </ul>
        </div>
      )}

      {activeTab === "users" && (
        <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
          <table className="w-full text-sm text-left">
            <thead className="bg-slate-50 border-b">
              <tr><th className="px-6 py-4">Name</th><th className="px-6 py-4">Email</th><th className="px-6 py-4">Role</th></tr>
            </thead>
            <tbody>
              {users?.map((u: any) => (
                <tr key={u.id} className="border-b">
                  <td className="px-6 py-4 font-medium">{u.name}</td>
                  <td className="px-6 py-4 text-slate-500">{u.email}</td>
                  <td className="px-6 py-4">
                    <select value={u.role} onChange={(e) => updateRole.mutate({ id: u.id, role: e.target.value })} className="border p-1 rounded bg-white">
                      <option value="citizen">Citizen</option>
                      <option value="field_worker">Field Worker</option>
                      <option value="operator">Operator</option>
                      <option value="admin">Admin</option>
                    </select>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}


      {activeTab === "categories" && (
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <h3 className="font-bold mb-4">Manage Categories</h3>
          <ul className="space-y-2">
            {categories?.map((c: any) => (
              <li key={c.id} className="p-3 bg-slate-50 rounded border flex justify-between items-center">
                <span>{c.name}</span>
                <Badge variant="outline">{c.id}</Badge>
              </li>
            ))}
          </ul>
        </div>
      )}

      {activeTab === "workflow" && (
        <div className="bg-white p-6 rounded-xl border shadow-sm space-y-3">
          <h3 className="font-bold mb-4">Status Transition Rules</h3>
          {workflow?.map((w: any) => (
            <div key={w.id} className="flex items-center gap-2 text-sm p-2 bg-slate-50 rounded">
              <span className="font-bold text-slate-700">{w.from_status}</span>
              <span className="text-slate-400">→</span>
              <span className="font-bold text-primary">{w.to_status}</span>
            </div>
          ))}
        </div>
      )}

      {activeTab === "workspace" && (
        <div className="bg-white p-6 rounded-xl border shadow-sm space-y-4">
          <h3 className="font-bold mb-4">Workspace Settings</h3>
          <div>
            <label className="block text-sm font-medium mb-1">Timezone</label>
            <input type="text" defaultValue={workspace?.timezone || "Asia/Kolkata"} className="border p-2 rounded w-full"
              onBlur={async (e) => { await fetch(`${API_URL}/admin/workspace`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ timezone: e.target.value }) }); }} />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Brand Color</label>
            <input type="color" defaultValue={workspace?.brand_color || "#176B61"} className="border p-2 rounded"
              onBlur={async (e) => { await fetch(`${API_URL}/admin/workspace`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ brand_color: e.target.value }) }); }} />
          </div>
        </div>
      )}
      {activeTab === "sla" && (
        <div className="bg-white p-6 rounded-xl border shadow-sm space-y-4">
          <h3 className="font-bold mb-4">SLA Configuration (Hours)</h3>
          {slas?.map((s: any) => (
            <div key={s.priority} className="flex items-center gap-4">
              <span className="w-24 font-medium">{s.priority}</span>
              <input type="number" defaultValue={s.hours} className="border p-2 rounded w-32" 
                onBlur={(e) => updateSla.mutate({ priority: s.priority, hours: parseInt(e.target.value) })} 
              />
              <span className="text-slate-500 text-sm">hours</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
