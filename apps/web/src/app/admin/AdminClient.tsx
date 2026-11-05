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
        {["wards", "departments", "users"].map(tab => (
          <button key={tab} onClick={() => setActiveTab(tab)} className={`px-4 py-2 font-medium capitalize border-b-2 ${activeTab === tab ? 'border-primary text-primary' : 'border-transparent text-slate-500'}`}>{tab}</button>
        ))}
      </div>

      {activeTab === "wards" && (
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <div className="flex gap-2 mb-4">
            <input id="wardName" className="border p-2 rounded w-full" placeholder="New Ward Name" />
            <Button onClick={() => { const el = document.getElementById('wardName') as HTMLInputElement; if(el.value) { addWard.mutate(el.value); el.value = ''; } }}>Add</Button>
          </div>
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
    </div>
  );
}
