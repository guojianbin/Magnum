namespace Magnum.RulesEngine
{
	using System.Collections.Generic;
	using System.Diagnostics;
	using System.Linq;
	using Collections;
	using ExecutionModel;

	public class SessionRuleContext<T> :
		RuleContext<T>
	{
		private readonly StatefulSession _session;
		private readonly MultiDictionary<WorkingMemoryElement<T>, Node> _activations;

		public SessionRuleContext(StatefulSession session, WorkingMemoryElement<T> item)
		{
			_session = session;
			_activations = new MultiDictionary<WorkingMemoryElement<T>, Node>(false, new KeyComparer(), new NodeComparer());

			Element = item;
		}

		public WorkingMemoryElement<T> Element { get; private set; }

		public void AddElementToAlphaMemory(WorkingMemoryElement<T> element, IEnumerable<Node> successors)
		{
			_activations.AddMany(element, successors);
		}

		public void DumpMemory()
		{
			_activations.Each(element =>
				{
					Trace.WriteLine("Element: " + element.Key.Object.GetType().Name);

					element.Value.Each(successor =>
						{
							Trace.WriteLine("  Successor: " + successor.NodeType);
						});
				});

		}

		private class KeyComparer :
			IEqualityComparer<WorkingMemoryElement<T>>
		{
			public bool Equals(WorkingMemoryElement<T> x, WorkingMemoryElement<T> y)
			{
				if ((x == null || y == null) && x != y)
					return false;

				if (x == null && y == null)
					return true;

				return ReferenceEquals(x.Object, y.Object);
			}

			public int GetHashCode(WorkingMemoryElement<T> obj)
			{
				return obj == null ? 0 : obj.Object.GetHashCode();
			}
		}

		private class NodeComparer :
			IEqualityComparer<Node>
		{
			public bool Equals(Node x, Node y)
			{
				if ((x == null || y == null) && x != y)
					return false;

				if (x == null && y == null)
					return true;

				return ReferenceEquals(x, y);
			}

			public int GetHashCode(Node node)
			{
				return node == null ? 0 : node.GetHashCode();
			}
		}
	}
}