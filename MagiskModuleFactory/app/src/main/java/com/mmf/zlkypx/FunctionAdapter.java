package com.mmf.zlkypx;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import java.util.List;

public class FunctionAdapter extends RecyclerView.Adapter<FunctionAdapter.VH> {

    private List<FunctionItem> items;
    private OnItemClickListener listener;

    public interface OnItemClickListener {
        void onItemClick(int position, FunctionItem item);
    }

    public FunctionAdapter(List<FunctionItem> items, OnItemClickListener listener) {
        this.items = items;
        this.listener = listener;
    }

    @NonNull
    @Override
    public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_function, parent, false);
        return new VH(v);
    }

    @Override
    public void onBindViewHolder(@NonNull VH holder, final int position) {
        final FunctionItem item = items.get(position);
        holder.tvIndex.setText(String.valueOf(position + 1));
        holder.tvTitle.setText(item.title);
        holder.tvDesc.setText(item.description);
        holder.itemView.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (listener != null) {
                    listener.onItemClick(position, item);
                }
            }
        });
    }

    @Override
    public int getItemCount() {
        return items.size();
    }

    static class VH extends RecyclerView.ViewHolder {
        TextView tvIndex, tvTitle, tvDesc;
        VH(View v) {
            super(v);
            tvIndex = v.findViewById(R.id.tvIndex);
            tvTitle = v.findViewById(R.id.tvTitle);
            tvDesc = v.findViewById(R.id.tvDesc);
        }
    }

    public static class FunctionItem {
        public String title;
        public String description;
        public int id;

        public FunctionItem(int id, String title, String description) {
            this.id = id;
            this.title = title;
            this.description = description;
        }
    }
}