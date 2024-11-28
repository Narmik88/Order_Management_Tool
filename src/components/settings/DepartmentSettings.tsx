import React, { useState, useEffect } from 'react';
import { Plus, Trash2, Edit2, Save, X } from 'lucide-react';
import { Department } from '../../types';
import { db } from '../../services/supabase';

export const DepartmentSettings: React.FC = () => {
  const [departments, setDepartments] = useState<Department[]>([]);
  const [editingDept, setEditingDept] = useState<string | null>(null);
  const [editedName, setEditedName] = useState('');
  const [newDeptName, setNewDeptName] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadDepartments();
  }, []);

  const loadDepartments = async () => {
    try {
      setLoading(true);
      setError(null);
      const deps = await db.getAllDepartments();
      setDepartments(deps);
    } catch (err) {
      console.error('Failed to load departments:', err);
      setError('Failed to load departments. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleAddDepartment = async () => {
    if (!newDeptName.trim()) return;
    
    try {
      setError(null);
      const newDept: Department = {
        name: newDeptName.trim(),
        agents: []
      };

      await db.saveDepartment(newDept);
      await loadDepartments();
      setNewDeptName('');
    } catch (err) {
      console.error('Failed to add department:', err);
      setError('Failed to add department. Please try again.');
    }
  };

  const handleDeleteDepartment = async (deptName: string) => {
    if (!window.confirm(`Are you sure you want to delete the ${deptName} department? This will also remove all agents in this department.`)) {
      return;
    }

    try {
      setError(null);
      await db.deleteDepartment(deptName);
      await loadDepartments();
    } catch (err) {
      console.error('Failed to delete department:', err);
      setError('Failed to delete department. Please try again.');
    }
  };

  const startEditing = (dept: Department) => {
    setEditingDept(dept.name);
    setEditedName(dept.name);
  };

  const handleUpdateDepartment = async (oldName: string) => {
    if (!editedName.trim() || oldName === editedName) {
      setEditingDept(null);
      return;
    }

    try {
      setError(null);
      const dept = departments.find(d => d.name === oldName);
      if (!dept) return;

      // First create the new department
      const updatedDept: Department = {
        ...dept,
        name: editedName.trim()
      };

      await db.saveDepartment(updatedDept);
      
      // Then delete the old one if the name changed
      if (oldName !== editedName) {
        await db.deleteDepartment(oldName);
      }
      
      await loadDepartments();
      setEditingDept(null);
    } catch (err) {
      console.error('Failed to update department:', err);
      setError('Failed to update department. Please try again.');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="text-gray-600">Loading departments...</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">Manage Departments</h2>

      {error && (
        <div className="bg-red-50 text-red-600 p-3 rounded-lg">
          {error}
        </div>
      )}

      <div className="flex gap-2">
        <input
          type="text"
          value={newDeptName}
          onChange={(e) => setNewDeptName(e.target.value)}
          placeholder="New department name"
          className="flex-1 rounded-lg border border-gray-300 px-4 py-2"
        />
        <button
          onClick={handleAddDepartment}
          disabled={!newDeptName.trim()}
          className="flex items-center px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Plus className="w-5 h-5 mr-2" />
          Add Department
        </button>
      </div>

      <div className="space-y-4">
        {departments.map((dept) => (
          <div key={dept.name} className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
            {editingDept === dept.name ? (
              <div className="flex items-center gap-2 flex-1">
                <input
                  type="text"
                  value={editedName}
                  onChange={(e) => setEditedName(e.target.value)}
                  className="flex-1 rounded-lg border border-gray-300 px-4 py-2"
                />
                <button
                  onClick={() => handleUpdateDepartment(dept.name)}
                  className="text-green-600 hover:text-green-700"
                >
                  <Save className="w-5 h-5" />
                </button>
                <button
                  onClick={() => setEditingDept(null)}
                  className="text-red-600 hover:text-red-700"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            ) : (
              <>
                <div>
                  <span className="font-medium">{dept.name}</span>
                  <span className="ml-2 text-sm text-gray-500">
                    ({dept.agents.length} agents)
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => startEditing(dept)}
                    className="text-indigo-600 hover:text-indigo-700"
                  >
                    <Edit2 className="w-5 h-5" />
                  </button>
                  <button
                    onClick={() => handleDeleteDepartment(dept.name)}
                    className="text-red-600 hover:text-red-700"
                  >
                    <Trash2 className="w-5 h-5" />
                  </button>
                </div>
              </>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};