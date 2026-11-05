"use client";
import { useEffect, useState } from "react";
import { API_URL } from "@/lib/api";
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar } from 'recharts';
import { ArrowLeft } from "lucide-react";
import Link from "next/link";

export default function Intelligence() {
  const [trends, setTrends] = useState([]);
  const [cats, setCats] = useState([]);

  useEffect(() => {
    fetch(`${API_URL}/analytics/trends`).then(r => r.json()).then(setTrends);
    fetch(`${API_URL}/analytics/summary`).then(r => r.json()).then(d => setCats(d.categories));
  }, []);

  return (
    <div className="min-h-screen bg-slate-50 p-8">
      <div className="max-w-6xl mx-auto">
        <Link href="/operations" className="flex items-center text-slate-500 mb-6 hover:text-primary"><ArrowLeft className="h-4 w-4 mr-2" /> Back to Ops</Link>
        <h1 className="text-3xl font-bold mb-8">Intelligence & Analytics</h1>
        
        <div className="grid grid-cols-2 gap-8">
          <div className="bg-white p-6 rounded-xl border shadow-sm">
            <h3 className="font-bold mb-4">Complaint Trends (Last 7 Days)</h3>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={trends}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="date" />
                  <YAxis />
                  <Tooltip />
                  <Line type="monotone" dataKey="count" stroke="#176b62" strokeWidth={3} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>
          <div className="bg-white p-6 rounded-xl border shadow-sm">
            <h3 className="font-bold mb-4">Issues by Category</h3>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={cats}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="category" />
                  <YAxis />
                  <Tooltip />
                  <Bar dataKey="count" fill="#176b62" />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
