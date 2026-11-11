/// Mức tiến độ việc con, để tô màu ô `x/y` trên thẻ bảng công việc.
///
/// Anh Nguyên (TNP, 11/11/2026): "5/10 đổ lại 1 màu, 6/10–8/10 1 màu, 9/10 1
/// màu, 10/10 1 màu". Việc không phải lúc nào cũng có đúng 10 việc con nên tính
/// theo phần trăm: dưới 60%, 60% tới dưới 90%, 90% tới dưới 100%, đủ 100%.
/// Web dùng cùng ngưỡng (`progressLevel` trong omni-flow).
enum ProgressLevel { low, mid, near, done }

/// `null` khi việc không có việc con (không có ô `x/y` để tô).
ProgressLevel? progressLevelOf(int done, int total) {
  if (total <= 0) return null;
  if (done >= total) return ProgressLevel.done;
  // So bằng số nguyên để 6/10 rơi đúng vào mức 2, không lệch vì làm tròn.
  if (done * 10 >= total * 9) return ProgressLevel.near;
  if (done * 10 >= total * 6) return ProgressLevel.mid;
  return ProgressLevel.low;
}
