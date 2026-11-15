// Index page: search over every English name, tabs, and sortable tables. Runs from disk (no network).
(function () {
  var input = document.getElementById("search");
  var results = document.getElementById("results");
  var index = window.WIKI_SEARCH || [];
  var MAX_RESULTS = 40;
  input.addEventListener("input", function () {
    var query = input.value.trim().toLowerCase();
    results.innerHTML = "";
    if (!query) return;
    var starts = [], contains = [];
    for (var i = 0; i < index.length; i++) {
      var name = index[i][0].toLowerCase();
      if (name.indexOf(query) === 0) starts.push(index[i]);
      else if (name.indexOf(query) > 0) contains.push(index[i]);
    }
    starts.concat(contains).slice(0, MAX_RESULTS).forEach(function (entry) {
      var item = document.createElement("li");
      var link = document.createElement("a");
      link.href = entry[2];
      link.textContent = entry[0];
      var kind = document.createElement("span");
      kind.className = "kind";
      kind.textContent = entry[1];
      item.appendChild(link);
      item.appendChild(kind);
      results.appendChild(item);
    });
  });
  input.addEventListener("keydown", function (event) {
    if (event.key === "Enter") {
      var first = results.querySelector("a");
      if (first) window.location.href = first.href;
    }
  });

  var buttons = document.querySelectorAll(".tabs button");
  buttons.forEach(function (button) {
    button.addEventListener("click", function () {
      buttons.forEach(function (other) { other.classList.toggle("active", other === button); });
      document.querySelectorAll(".tab").forEach(function (tab) { tab.hidden = tab.id !== "tab-" + button.dataset.tab; });
    });
  });

  document.querySelectorAll("table.sortable").forEach(function (table) {
    var headers = table.querySelectorAll("th");
    headers.forEach(function (header, column) {
      if (!header.dataset.sort) return;
      header.addEventListener("click", function () {
        var numeric = header.dataset.sort === "number";
        var descending = header.classList.contains("asc") ? true : header.classList.contains("desc") ? false : numeric;
        headers.forEach(function (other) { other.classList.remove("asc", "desc"); });
        header.classList.add(descending ? "desc" : "asc");
        var body = table.tBodies[0];
        var rows = Array.prototype.slice.call(body.rows);
        rows.sort(function (rowA, rowB) {
          var a = rowA.cells[column].textContent.trim(), b = rowB.cells[column].textContent.trim();
          var order = numeric ? (parseFloat(a) || 0) - (parseFloat(b) || 0) : a.localeCompare(b);
          return descending ? -order : order;
        });
        rows.forEach(function (row) { body.appendChild(row); });
      });
    });
  });
})();
