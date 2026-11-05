"use client";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { API_URL } from "@/lib/api";

export default function Admin() {
  const [wardName, setWardName] = useState("");
  const [deptName, setDeptName] = useState("");
  const [msg, setMsg] = useState("");

  const addWard = async () => {
    await fetch(`${API_URL}/admin/wards`, { method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({name: wardName, code: "W-NEW"}) });
    setMsg("Ward added!");
  };

  const addDept = async () => {
    await fetch(`${API_URL}/admin/departments`, { method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({name: deptName}) });
    setMsg("Department added!");
  };

  return (
    <div className="p-10 max-w-2xl mx-auto space-y-8">
      <h1 className="text-3xl font-bold">Admin Configuration</h1>
      {msg && <div className="bg-green-100 p-3 rounded text-green-800">{msg}</div>}
      <div className="bg-white p-6 border rounded-xl shadow-sm">
        <h3 className="font-bold mb-4">Add Ward</h3>
        <input className="border p-2 rounded w-full mb-2" placeholder="Ward Name" onChange={e => setWardName(e.target.value)} />
        <Button onClick={addWard}>Create Ward</Button>
      </div>
      <div className="bg-white p-6 border rounded-xl shadow-sm">
        <h3 className="font-bold mb-4">Add Department</h3>
        <input className="border p-2 rounded w-full mb-2" placeholder="Department Name" onChange={e => setDeptName(e.target.value)} />
        <Button onClick={addDept}>Create Department</Button>
      </div>
    </div>
  );
}
